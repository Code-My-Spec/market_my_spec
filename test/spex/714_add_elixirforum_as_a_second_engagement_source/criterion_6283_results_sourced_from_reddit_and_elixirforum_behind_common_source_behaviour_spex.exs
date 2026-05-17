defmodule MarketMySpecSpex.Story714.Criterion6283Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6283 — Results are sourced from Reddit and ElixirForum
  behind a common Source behaviour so adding a third platform later
  is additive.

  Polymorphic dispatch: one search_engagements call against an account
  with one Reddit venue + one ElixirForum venue produces candidates
  from BOTH sources.

  Test infrastructure: ReqCassette serves recorded HTTP responses for
  both Reddit and ElixirForum via `with_mixed_cassette/2`. Record once
  in `:record` mode; replay forever after. See
  `test/support/elixir_forum_spex_helpers.ex` for the recording
  workflow.

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

  spex "single search call returns candidates from BOTH Reddit and ElixirForum sources" do
    scenario "Account with one Reddit + one ElixirForum venue → response has at least one of each" do
      given_ "an account with one Reddit venue and one ElixirForum venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        Fixtures.venue_fixture(scope, %{
          source: :elixirforum,
          identifier: "phoenix-forum",
          enabled: true
        })

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called (replays recorded cassette)", context do
        {:reply, resp, _} =
          ElixirForumHelpers.with_mixed_cassette("crit_6283_mixed_sources", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "candidates include at least one Reddit and at least one ElixirForum source", context do
        candidates = context.payload["candidates"] || []
        refute Enum.empty?(candidates), "expected candidates from both sources"

        sources =
          candidates
          |> Enum.map(&(&1["source"] || &1[:source]))
          |> Enum.map(&to_string/1)
          |> Enum.uniq()
          |> Enum.sort()

        assert "reddit" in sources, "expected reddit in #{inspect(sources)}"
        assert "elixirforum" in sources, "expected elixirforum in #{inspect(sources)}"

        {:ok, context}
      end
    end
  end
end
