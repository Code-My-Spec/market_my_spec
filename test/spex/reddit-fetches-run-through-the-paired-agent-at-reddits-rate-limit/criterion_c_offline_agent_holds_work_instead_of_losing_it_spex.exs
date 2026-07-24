defmodule MarketMySpecSpex.RedditQueue.OfflineAgentHoldsWorkSpex do
  @moduledoc """
  Reddit fetches run through the paired MMS Agent at Reddit's rate limit.

  Criterion — with no agent online, queued work waits instead of being lost
  or falling back to the server's IP.

  This is the failure mode that matters most in production. The agent exists
  because the datacenter IP is throttled, so "no agent online" must never
  degrade into "fetch from the server anyway" — and at ~1 request/minute,
  silently failing a job also isn't acceptable: it would take minutes to
  notice and minutes more to redo.

  So an offline agent must leave the job `pending`, un-attempted, and must
  not perform any HTTP.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.RedditFetchJob
  alias MarketMySpec.Engagements.RedditFetchQueue
  alias MarketMySpec.Engagements.RedditFetchQueue.Drain
  alias MarketMySpec.Engagements.Search
  alias MarketMySpec.Repo
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  # Forces the production transport (dispatch to a paired binary) rather
  # than test's `:direct`, so "no agent online" is actually reachable.
  defp with_agent_transport(fun), do: RedditHelpers.with_agent_transport(fun)

  spex "Queued Reddit work survives an offline agent" do
    scenario "Draining with no online agent leaves the job pending and untouched" do
      given_ "a queued search fetch and no paired agent", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        {:ok, job} =
          RedditHelpers.with_deferred_drain(fn ->
            RedditFetchQueue.enqueue_search(scope, venue, "phoenix")
          end)

        assert job.status == :pending

        {:ok, Map.merge(context, %{scope: scope, venue: venue, job: job})}
      end

      when_ "the drain runs against the agent transport", context do
        # No cassette is installed. If the drain fetched anything, ReqCassette
        # would not be in the pipeline and a real network call would be
        # attempted — so reaching the assertions at all is part of the proof.
        outcome =
          with_agent_transport(fn ->
            {:ok, claimed} = RedditFetchQueue.claim_next()
            Drain.perform(claimed)
          end)

        {:ok, Map.put(context, :outcome, outcome)}
      end

      then_ "the job goes back to pending with its attempt refunded", context do
        assert context.outcome == :offline,
               "expected the drain to report :offline; got: #{inspect(context.outcome)}"

        reloaded = Repo.get!(RedditFetchJob, context.job.id)

        assert reloaded.status == :pending,
               "an offline agent must not consume the job; status was #{reloaded.status}"

        assert reloaded.attempts == 0,
               "the attempt should be refunded, not spent; got #{reloaded.attempts}"

        assert is_nil(reloaded.completed_at), "job should not be completed"
        assert is_nil(reloaded.last_error), "offline is not an error on the job"

        assert RedditFetchQueue.pending_count(context.scope) == 1,
               "the work must still be queued"

        {:ok, context}
      end

      then_ "a search still answers, reporting the work as queued", context do
        result =
          RedditHelpers.with_deferred_drain(fn ->
            Search.search(context.scope, "phoenix")
          end)

        assert result.failures == [],
               "a waiting queue is not a venue failure; got: #{inspect(result.failures)}"

        assert Enum.any?(result.notices, &String.contains?(&1, "queued")),
               "expected a queued notice; got: #{inspect(result.notices)}"

        {:ok, context}
      end
    end

    scenario "Re-running a search does not multiply the queue" do
      given_ "a Reddit venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})
        {:ok, Map.merge(context, %{scope: scope, venue: venue})}
      end

      when_ "the same search is run three times without draining", context do
        RedditHelpers.with_deferred_drain(fn ->
          Enum.each(1..3, fn _ ->
            Search.search(context.scope, "phoenix")
          end)
        end)

        {:ok, context}
      end

      then_ "exactly one fetch is queued", context do
        assert RedditFetchQueue.pending_count(context.scope) == 1,
               "re-running a search must refresh the pending job, not stack up " <>
                 "duplicates — at ~1 request/minute a stacked queue is minutes of " <>
                 "wasted budget"

        {:ok, context}
      end
    end
  end
end
