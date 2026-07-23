defmodule MarketMySpecSpex.RedditQueue.AgentDisconnectRequeuesSpex do
  @moduledoc """
  Reddit fetches run through the paired MMS Agent at Reddit's rate limit.

  Criterion — an agent that drops mid-fetch returns the job to the queue.

  At ~1 request/minute a lost job is minutes of throughput, so a disconnect
  must be distinguishable from a fetch that actually failed: the job goes
  back to `pending` with its attempt refunded and no `last_error`, ready for
  the binary to pick up when it reconnects.

  Its own module (rather than a second scenario alongside the happy path)
  because these spex accumulate real shared state — PubSub subscriptions,
  a channel socket, and queue rows — and a leaked subscription from a prior
  scenario silently answers the wrong assertion.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.RedditFetchJob
  alias MarketMySpec.Engagements.RedditFetchQueue
  alias MarketMySpec.Engagements.RedditFetchQueue.Drain
  alias MarketMySpec.Repo
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  defp sign_in(conn, user) do
    {tok, _} = Fixtures.generate_user_magic_link_token(user)
    post(conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
  end

  spex "A mid-flight agent disconnect returns the job to the queue" do
    scenario "A mid-flight agent disconnect returns the job to the queue" do
      given_ "a paired, online agent and a queued fetch", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        conn = sign_in(context.conn, user)
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")
        {:ok, _, socket} = Fixtures.join_agent_channel(user.id, agent.id, token)
        Fixtures.subscribe_to_agent_topic(user.id)

        {:ok, job} =
          RedditHelpers.with_deferred_drain(fn ->
            RedditFetchQueue.enqueue_search(scope, venue, "phoenix")
          end)

        {:ok, Map.merge(context, %{scope: scope, job: job, socket: socket})}
      end

      when_ "the agent drops before replying", context do
        caller = self()
        job_id = context.job.id

        RedditHelpers.with_agent_transport(fn ->
          spawn_link(fn ->
            {:ok, claimed} = RedditFetchQueue.claim(job_id)
            send(caller, {:drain_outcome, Drain.perform(claimed)})
          end)

          _envelope = Fixtures.expect_reddit_fetch_envelope()
          Fixtures.kill_channel(context.socket)
        end)

        outcome =
          receive do
            {:drain_outcome, o} -> o
          after
            10_000 -> flunk("drain did not finish after the agent disconnected")
          end

        {:ok, Map.put(context, :outcome, outcome)}
      end

      then_ "the job is pending again rather than failed", context do
        assert context.outcome == :offline,
               "a mid-flight disconnect is not the job's fault; got: #{inspect(context.outcome)}"

        reloaded = Repo.get!(RedditFetchJob, context.job.id)

        assert reloaded.status == :pending,
               "expected the job requeued; status was #{reloaded.status}"

        assert is_nil(reloaded.last_error),
               "a disconnect must not be recorded as a fetch error"

        {:ok, context}
      end
    end
  end
end
