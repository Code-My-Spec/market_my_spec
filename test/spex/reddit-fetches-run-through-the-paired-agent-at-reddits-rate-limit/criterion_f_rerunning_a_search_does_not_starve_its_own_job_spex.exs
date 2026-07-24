defmodule MarketMySpecSpex.RedditQueue.RerunDoesNotStarveJobSpex do
  @moduledoc """
  Reddit fetches run through the paired MMS Agent at Reddit's rate limit.

  Criterion — re-running a search keeps its job's place in the queue.

  The drain is FIFO on `enqueued_at`, and enqueueing is idempotent per unit
  of work. Those two facts interact badly if the idempotent path refreshes
  `enqueued_at`: every re-request moves the job to the BACK of the line.

  That is not a theoretical ordering nit — the only way to find out whether
  your results arrived is to run the search again, so the act of waiting for
  a job is what starves it. Caught in production: a queue drained from 8 to 4
  jobs while one re-requested job never advanced.

  Pins the ordering guarantee directly: an older job stays ahead of a newer
  one no matter how many times the older one is re-requested.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.RedditFetchJob
  alias MarketMySpec.Engagements.RedditFetchQueue
  alias MarketMySpec.Repo
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  spex "Re-running a search does not send its own job to the back of the queue" do
    scenario "An older job still drains first after the newer one is re-requested" do
      given_ "two queued searches, the first enqueued before the second", context do
        scope = Fixtures.account_scoped_user_fixture()
        first = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})
        second = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming"})

        {:ok, older} =
          RedditHelpers.with_deferred_drain(fn ->
            RedditFetchQueue.enqueue_search(scope, first, "phoenix")
          end)

        # Force a distinct enqueued_at — the column is second-granularity, so
        # without this both rows can share a timestamp and the assertion would
        # be decided by the id tiebreak rather than by ordering.
        backdate(older, -60)

        {:ok, newer} =
          RedditHelpers.with_deferred_drain(fn ->
            RedditFetchQueue.enqueue_search(scope, second, "phoenix")
          end)

        {:ok, Map.merge(context, %{scope: scope, first: first, older: older, newer: newer})}
      end

      when_ "the older search is re-requested several times while it waits", context do
        RedditHelpers.with_deferred_drain(fn ->
          Enum.each(1..3, fn _ ->
            RedditFetchQueue.enqueue_search(context.scope, context.first, "phoenix")
          end)
        end)

        {:ok, context}
      end

      then_ "no duplicate job was created", context do
        assert RedditFetchQueue.pending_count(context.scope) == 2,
               "re-requesting must refresh the pending job, not stack duplicates"

        {:ok, context}
      end

      then_ "the older job is still the one the drain claims first", context do
        {:ok, claimed} = RedditFetchQueue.claim_next()

        assert claimed.id == context.older.id,
               "expected the older job (#{context.older.id}) to drain first, got " <>
                 "#{claimed.id} — re-requesting a search must not move it behind " <>
                 "work that was asked for later"

        {:ok, context}
      end

      then_ "its original queue position was preserved, not refreshed", context do
        reloaded = Repo.get!(RedditFetchJob, context.older.id)

        assert DateTime.compare(reloaded.enqueued_at, context.newer.enqueued_at) == :lt,
               "enqueued_at must still predate the newer job; it was refreshed to " <>
                 "#{inspect(reloaded.enqueued_at)}"

        {:ok, context}
      end
    end
  end

  defp backdate(job, seconds) do
    at = DateTime.utc_now() |> DateTime.add(seconds, :second) |> DateTime.truncate(:second)

    job
    |> Ecto.Changeset.change(enqueued_at: at)
    |> Repo.update!()
  end
end
