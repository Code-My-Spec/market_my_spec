defmodule MarketMySpecSpex.RedditQueue.SearchEnqueuesAndServesSpex do
  @moduledoc """
  Reddit fetches run through the paired MMS Agent at Reddit's rate limit.

  Criterion — a search enqueues work and serves the drained result.

  Reddit meters anonymous RSS at ~1 request per 60s per IP, so a search
  cannot fetch inline. This pins the two-phase contract:

    1. The first search for a venue+query returns zero candidates, does NOT
       report a failure, and says the fetch is queued.
    2. Once the queue drains, the same search returns the candidates without
       issuing another request.

  Drain is deferred via `with_deferred_drain/1` so the two phases are
  observable separately — under the default test config they collapse into
  one call.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.RedditFetchQueue
  alias MarketMySpec.Engagements.RedditFetchQueue.Drain
  alias MarketMySpec.Engagements.Search
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  spex "A Reddit search enqueues a fetch and serves the result after the drain" do
    scenario "First search is queued and empty; after draining it carries candidates" do
      given_ "an enabled Reddit venue and a cassette with two results", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        RedditHelpers.build_search_cassette!("reddit_queue_two_hits",
          subreddit: "elixir",
          query: "phoenix",
          children: [
            %{id: "q1", title: "Phoenix LiveView question"},
            %{id: "q2", title: "Phoenix deployment question"}
          ]
        )

        {:ok, Map.merge(context, %{scope: scope, venue: venue})}
      end

      when_ "the founder searches before anything has drained", context do
        result =
          RedditHelpers.with_deferred_drain(fn ->
            Search.search(context.scope, "phoenix")
          end)

        {:ok, Map.put(context, :first_result, result)}
      end

      then_ "the search reports queued work rather than a failure", context do
        %{candidates: candidates, failures: failures, notices: notices} = context.first_result

        assert candidates == [],
               "expected no candidates before the drain, got: #{inspect(candidates)}"

        assert failures == [],
               "a queued fetch is not a failure; got: #{inspect(failures)}"

        assert Enum.any?(notices, &String.contains?(&1, "queued")),
               "expected a queued notice; got: #{inspect(notices)}"

        assert RedditFetchQueue.pending_count(context.scope) == 1,
               "expected exactly one pending job"

        {:ok, context}
      end

      when_ "the queue drains and the founder searches again", context do
        drained =
          RedditHelpers.with_deferred_drain(fn ->
            RedditHelpers.with_reddit_cassette("reddit_queue_two_hits", fn ->
              Drain.drain_to_empty()
            end)
          end)

        second =
          RedditHelpers.with_deferred_drain(fn ->
            Search.search(context.scope, "phoenix")
          end)

        {:ok, Map.merge(context, %{drained: drained, second_result: second})}
      end

      then_ "the drained candidates are served without a new request", context do
        assert context.drained == 1, "expected one job to drain, got #{context.drained}"

        %{candidates: candidates, failures: failures, notices: notices} = context.second_result

        titles = Enum.map(candidates, &Map.get(&1, "title"))

        assert length(candidates) == 2,
               "expected both cassette results, got: #{inspect(titles)}"

        assert "Phoenix LiveView question" in titles, "got: #{inspect(titles)}"
        assert "Phoenix deployment question" in titles, "got: #{inspect(titles)}"
        assert failures == [], "got: #{inspect(failures)}"

        # The second search had no cassette wrapped around it. If it had hit
        # the network the cassette plug would be absent and the call would
        # fail — reaching here proves the read came from the queue.
        assert Enum.any?(notices, &String.contains?(&1, "results from")),
               "expected a staleness notice naming the fetch age; got: #{inspect(notices)}"

        {:ok, context}
      end
    end
  end
end
