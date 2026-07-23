defmodule MarketMySpecSpex.Story714.Criterion6287Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6287 — Cross-source ordering interleaves per-source ranked
  lists.

  Interleave (not concat): if Reddit returns [R1, R2, R3] in source-
  ranked order and ElixirForum returns [F1, F2, F3], the merged result
  alternates sources at the top of the merged list (not all-Reddit-
  then-all-Forum). Avoids single-source dominance when one source
  returns many more candidates than the other.

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

  spex "cross-source results interleave, not concat" do
    scenario "Reddit returns multiple, ElixirForum returns multiple; first three positions cover both sources" do
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
          ElixirForumHelpers.with_mixed_cassette("crit_6287_interleave", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "the first three positions cover BOTH sources (no all-of-one-then-all-of-other concat)",
            context do
        candidates = context.payload["candidates"] || []
        assert length(candidates) >= 4, "need >=4 candidates to observe interleave; got #{length(candidates)}"

        first_three_sources =
          candidates
          |> Enum.take(3)
          |> Enum.map(&(&1["source"] || &1[:source]))
          |> Enum.map(&to_string/1)

        distinct = first_three_sources |> Enum.uniq() |> length()

        assert distinct >= 2,
               "expected interleave (>=2 distinct sources in first 3); got: #{inspect(first_three_sources)}"

        all_sources =
          candidates
          |> Enum.map(&(&1["source"] || &1[:source]))
          |> Enum.map(&to_string/1)

        half = div(length(all_sources), 2)
        first_half = Enum.take(all_sources, half)
        second_half = Enum.drop(all_sources, half)

        refute Enum.uniq(first_half) == ["reddit"] and Enum.uniq(second_half) == ["elixirforum"],
               "expected interleave, not concat; got: #{inspect(all_sources)}"

        refute Enum.uniq(first_half) == ["elixirforum"] and Enum.uniq(second_half) == ["reddit"],
               "expected interleave, not concat; got: #{inspect(all_sources)}"

        {:ok, context}
      end
    end
  end
end
