defmodule MarketMySpecSpex.Story714.Criterion6393Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6393 — Reddit and ElixirForum candidates in one response
  have identical key sets.

  Sister to 6284. Cross-source key-set equality observed in a single
  envelope.

  Test infrastructure: ReqCassette via `with_mixed_cassette/2`.

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

  spex "single response → both sources present → identical sorted key sets" do
    scenario "Decode response; group by source; assert keys equal across groups" do
      given_ "one venue per source", context do
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
          ElixirForumHelpers.with_mixed_cassette("crit_6393_key_set_parity", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "Reddit candidate key set == ElixirForum candidate key set (sorted equality)", context do
        candidates = context.payload["candidates"] || []
        assert length(candidates) >= 2, "need >=1 candidate per source"

        reddit = Enum.find(candidates, &(to_string(&1["source"] || &1[:source]) == "reddit"))
        forum = Enum.find(candidates, &(to_string(&1["source"] || &1[:source]) == "elixirforum"))

        assert reddit, "expected reddit candidate in envelope"
        assert forum, "expected elixirforum candidate in envelope"

        reddit_keys = reddit |> Map.keys() |> Enum.sort()
        forum_keys = forum |> Map.keys() |> Enum.sort()

        assert reddit_keys == forum_keys,
               "expected identical key sets; reddit=#{inspect(reddit_keys)}, forum=#{inspect(forum_keys)}"

        {:ok, context}
      end
    end
  end
end
