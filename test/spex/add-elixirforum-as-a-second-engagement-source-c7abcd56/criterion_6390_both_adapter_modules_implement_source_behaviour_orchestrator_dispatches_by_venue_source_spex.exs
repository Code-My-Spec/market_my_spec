defmodule MarketMySpecSpex.Story714.Criterion6390Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6390 — Both adapter modules implement the Source behaviour
  and the orchestrator dispatches by venue.source.

  Sister to 6283. Direct contract check that both adapter modules
  declare `@behaviour MarketMySpec.Engagements.Source` PLUS the
  end-to-end observation that one search call produces candidates
  from both adapters (proves dispatch routes by source).

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

  spex "Source behaviour declared on both adapters; orchestrator dispatches by venue.source" do
    scenario "Check @behaviour attribute on both adapters; one search call returns from both" do
      given_ "Source behaviour exists; both adapters loaded; one venue per source", context do
        behaviour_module = MarketMySpec.Engagements.Source

        assert Code.ensure_loaded?(behaviour_module),
               "expected #{inspect(behaviour_module)} behaviour module to exist"

        reddit_adapter = MarketMySpec.Engagements.Source.Reddit
        forum_adapter = MarketMySpec.Engagements.Source.ElixirForum

        for {mod, label} <- [{reddit_adapter, "Reddit"}, {forum_adapter, "ElixirForum"}] do
          assert Code.ensure_loaded?(mod),
                 "expected #{label} adapter module #{inspect(mod)} to exist"

          behaviours =
            mod.module_info(:attributes)
            |> Keyword.get_values(:behaviour)
            |> List.flatten()

          assert behaviour_module in behaviours,
                 "expected #{inspect(mod)} to implement #{inspect(behaviour_module)}; got behaviours: #{inspect(behaviours)}"
        end

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
          ElixirForumHelpers.with_mixed_cassette("crit_6390_behaviour_dispatch", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "candidates include at least one from each source (orchestrator dispatched to both)",
            context do
        candidates = context.payload["candidates"] || []
        refute Enum.empty?(candidates)

        sources =
          candidates
          |> Enum.map(&(&1["source"] || &1[:source]))
          |> Enum.map(&to_string/1)
          |> Enum.uniq()
          |> Enum.sort()

        assert "reddit" in sources, "expected reddit dispatch; got: #{inspect(sources)}"
        assert "elixirforum" in sources, "expected elixirforum dispatch; got: #{inspect(sources)}"

        {:ok, context}
      end
    end
  end
end
