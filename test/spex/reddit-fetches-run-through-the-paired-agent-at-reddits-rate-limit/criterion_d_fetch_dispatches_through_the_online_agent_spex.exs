defmodule MarketMySpecSpex.RedditQueue.DispatchesThroughAgentSpex do
  @moduledoc """
  Reddit fetches run through the paired MMS Agent at Reddit's rate limit.

  Criterion — a queued fetch is dispatched to the user's online agent, and
  the agent's reply becomes candidates.

  This is the end-to-end agent hop, driven against the real channel: the
  spex plays the binary (subscribes to the user topic, receives the
  `reddit_fetch` envelope, replies with a `reddit_result`) while the drain
  runs the job. It also pins the envelope's security property — the wire
  carries a path, never a URL or host — which is what makes it impossible
  to steer the binary at anything but Reddit RSS.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.RedditFetchJob
  alias MarketMySpec.Engagements.RedditFetchQueue
  alias MarketMySpec.Engagements.RedditFetchQueue.Drain
  alias MarketMySpec.Repo
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  defp feed(entries) do
    ~s(<?xml version="1.0" encoding="UTF-8"?>) <>
      ~s(<feed xmlns="http://www.w3.org/2005/Atom"><title>elixir</title>) <>
      Enum.join(entries, "") <>
      ~s(</feed>)
  end

  defp entry(id, title) do
    ~s(<entry><id>t3_#{id}</id><title>#{title}</title>) <>
      ~s(<link href="https://www.reddit.com/r/elixir/comments/#{id}/x/" />) <>
      ~s(<author><name>/u/someone</name></author>) <>
      ~s(<published>2026-07-01T00:00:00Z</published>) <>
      ~s(<updated>2026-07-01T00:00:00Z</updated>) <>
      ~s(<content type="html">body</content></entry>)
  end

  defp sign_in(conn, user) do
    {tok, _} = Fixtures.generate_user_magic_link_token(user)
    post(conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
  end

  spex "A queued fetch runs on the paired agent and its reply becomes candidates" do
    scenario "The drain dispatches to the online agent and persists what it returns" do
      given_ "a paired, online agent and a queued search fetch", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        conn = sign_in(context.conn, user)
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")
        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent.id, token)
        Fixtures.subscribe_to_agent_topic(user.id)

        {:ok, job} =
          RedditHelpers.with_deferred_drain(fn ->
            RedditFetchQueue.enqueue_search(scope, venue, "phoenix")
          end)

        {:ok, Map.merge(context, %{scope: scope, venue: venue, job: job})}
      end

      when_ "the drain runs the job while the spex plays the binary", context do
        caller = self()
        job_id = context.job.id

        RedditHelpers.with_agent_transport(fn ->
          spawn_link(fn ->
            {:ok, claimed} = RedditFetchQueue.claim(job_id)
            send(caller, {:drain_outcome, Drain.perform(claimed)})
          end)

          envelope = Fixtures.expect_reddit_fetch_envelope()
          send(caller, {:envelope, envelope})

          Fixtures.respond_to_envelope(
            envelope,
            200,
            feed([entry("d1", "Phoenix streams question"), entry("d2", "Phoenix auth question")])
          )
        end)

        envelope =
          receive do
            {:envelope, e} -> e
          after
            5_000 -> flunk("no reddit_fetch envelope observed")
          end

        outcome =
          receive do
            {:drain_outcome, o} -> o
          after
            5_000 -> flunk("drain did not finish")
          end

        {:ok, Map.merge(context, %{envelope: envelope, outcome: outcome})}
      end

      then_ "the envelope carries a Reddit RSS path and no URL or host", context do
        env = context.envelope

        assert env["path"] == "/r/elixir/search.rss",
               "expected the search feed path; got: #{inspect(env["path"])}"

        assert env["kind"] == "search"

        refute Map.has_key?(env, "url"),
               "the wire must not carry a URL — the binary owns the base URL"

        refute Enum.any?(Map.values(env), fn v ->
                 is_binary(v) and String.contains?(v, "://")
               end),
               "no absolute URL may appear anywhere in the envelope: #{inspect(env)}"

        # Params ride as ordered pairs so the query string is byte-stable.
        assert ["q", "phoenix"] in env["params"],
               "expected the query param; got: #{inspect(env["params"])}"

        {:ok, context}
      end

      then_ "the job completes with the candidates the agent returned", context do
        assert context.outcome == :ok, "drain outcome: #{inspect(context.outcome)}"

        reloaded = Repo.get!(RedditFetchJob, context.job.id)

        assert reloaded.status == :done, "job status: #{reloaded.status}"

        titles = Enum.map(reloaded.candidates, &Map.get(&1, "title"))

        assert length(reloaded.candidates) == 2,
               "expected both entries parsed from the agent's feed; got: #{inspect(titles)}"

        assert "Phoenix streams question" in titles, "got: #{inspect(titles)}"

        {:ok, context}
      end

      then_ "a search now serves those candidates from the queue", context do
        result =
          RedditHelpers.with_deferred_drain(fn ->
            MarketMySpec.Engagements.Search.search(context.scope, "phoenix")
          end)

        titles = Enum.map(result.candidates, &Map.get(&1, "title"))

        assert "Phoenix streams question" in titles,
               "search should serve the agent-fetched candidates; got: #{inspect(titles)}"

        assert result.failures == [], "got: #{inspect(result.failures)}"

        {:ok, context}
      end
    end
  end
end
