defmodule MarketMySpecSpex.Story714.Criterion6284Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6284 — Reddit and ElixirForum candidates share the same
  shape.

  Canonical candidate fields: thread_id, title, source, url, score,
  reply_count, recency, snippet, engagement.

  Test infrastructure: ReqCassette via `with_mixed_cassette/2` (record-
  and-replay; see helpers moduledoc).

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.ElixirForumHelpers
  alias MarketMySpecSpex.Fixtures

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

  spex "Reddit and ElixirForum candidates share identical key set" do
    scenario "One Reddit candidate + one ElixirForum candidate; both expose canonical keys" do
      given_ "one Reddit venue + one ElixirForum venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        Fixtures.venue_fixture(scope, %{
          source: :elixirforum,
          identifier: "phoenix-forum",
          enabled: true
        })

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, resp, _} =
          ElixirForumHelpers.with_mixed_cassette("crit_6284_shape_parity", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "candidates have identical key sets across both sources (canonical contract)", context do
        candidates = context.payload["candidates"] || []
        refute Enum.empty?(candidates), "expected at least one candidate per source"

        canonical_required = ~w(thread_id title source url score reply_count recency snippet)

        for candidate <- candidates do
          source_label = to_string(candidate["source"] || candidate[:source])

          for key <- canonical_required do
            assert Map.has_key?(candidate, key),
                   "expected key #{inspect(key)} on #{source_label} candidate; got: #{inspect(Map.keys(candidate))}"
          end
        end

        # Group by source; assert key sets identical between groups
        by_source =
          candidates
          |> Enum.group_by(&to_string(&1["source"] || &1[:source]))

        reddit_keys = by_source["reddit"] |> List.first() |> Map.keys() |> Enum.sort()
        forum_keys = by_source["elixirforum"] |> List.first() |> Map.keys() |> Enum.sort()

        assert reddit_keys == forum_keys,
               "expected identical key sets; reddit=#{inspect(reddit_keys)}, forum=#{inspect(forum_keys)}"

        {:ok, context}
      end
    end
  end
end
