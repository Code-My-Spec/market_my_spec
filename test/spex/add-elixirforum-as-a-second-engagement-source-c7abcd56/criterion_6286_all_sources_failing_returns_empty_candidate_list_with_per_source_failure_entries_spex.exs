defmodule MarketMySpecSpex.Story714.Criterion6286Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6286 — All sources failing returns an empty candidate list
  with per-source failure entries.

  Complete-failure shape: envelope is `%{candidates: [], failures:
  [...]}`, not an exception. One failure entry per failing source.

  Test infrastructure: ReqCassette via `with_mixed_cassette/2` records
  both sources returning failures.

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

  spex "all sources failing → empty candidates + one failure entry per source" do
    scenario "Reddit + ElixirForum both fail → candidates [], failures has both sources" do
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
          ElixirForumHelpers.with_mixed_cassette("crit_6286_all_sources_fail", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "candidates empty; failures has at least one entry per source", context do
        candidates = context.payload["candidates"] || []
        failures = context.payload["failures"] || []

        assert candidates == [], "expected empty candidates when all sources fail"

        sources =
          failures
          |> Enum.map(&(&1["source"] || &1[:source]))
          |> Enum.map(&to_string/1)
          |> Enum.uniq()
          |> Enum.sort()

        assert "reddit" in sources, "expected reddit failure entry; got: #{inspect(sources)}"

        assert "elixirforum" in sources,
               "expected elixirforum failure entry; got: #{inspect(sources)}"

        {:ok, context}
      end
    end
  end
end
