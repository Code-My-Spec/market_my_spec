defmodule MarketMySpecSpex.Story705.Criterion6318Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6318 — Each candidate carries an `engagement` summary:
  count (integer), latest_state (`:staged | :posted | :abandoned | nil`),
  latest_angle (string | nil), latest_posted_at (datetime | nil).

  This pin asserts the engagement key always present and always shaped
  correctly. The nil/zero case (no touchpoints) is criterion 6319; the
  populated case (with touchpoints) is criterion 6350 (depends on story
  716 schema). Here we just pin the key shape.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "every candidate has an engagement summary key with the expected sub-keys" do
    scenario "a fresh thread's candidate carries engagement: %{count, latest_state, latest_angle, latest_posted_at}" do
      given_ "an account with one enabled r/elixir venue and a one-thread cassette",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", enabled: true
        })

        RedditHelpers.build_search_cassette!("crit_6318_engagement_shape",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Engagement-shape probe", score: 1, num_comments: 0,
              id: "eng1", permalink: "/r/elixir/comments/eng1/_/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6318_engagement_shape", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the candidate has an `engagement` map with count, latest_state, latest_angle, latest_posted_at",
            context do
        [c] = context.payload["candidates"]

        assert Map.has_key?(c, "engagement"),
               "expected candidate to carry an `engagement` key; got: #{inspect(Map.keys(c))}"

        engagement = c["engagement"]
        assert is_map(engagement), "expected engagement to be a map"

        for key <- ~w(count latest_state latest_angle latest_posted_at) do
          assert Map.has_key?(engagement, key),
                 "expected engagement to have key '#{key}'; got: #{inspect(Map.keys(engagement))}"
        end

        assert is_integer(engagement["count"])
        # latest_* are nullable; just assert key presence (checked above)
        {:ok, context}
      end
    end
  end
end
