defmodule MarketMySpecSpex.Story714.Criterion6396Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6396 — High-weight ElixirForum candidate outranks
  low-weight Reddit candidate with same per-source signal.

  Sister to 6287 (interleave). The cross-source ordering function
  respects per-source weights: ElixirForum venue (weight 1.0) ranks
  ahead of Reddit venue (weight 0.1) when per-source signals are
  comparable.

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

  spex "weighted cross-source ordering: high-weight ElixirForum > low-weight Reddit at parity" do
    scenario "Reddit weight 0.1; ElixirForum weight 1.0; comparable signal → forum ranks first" do
      given_ "one Reddit venue (weight 0.1) + one ElixirForum venue (weight 1.0)", context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit,
          identifier: "elixir",
          weight: 0.1,
          enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :elixirforum,
          identifier: "phoenix-forum",
          weight: 1.0,
          enabled: true
        })

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, resp, _} =
          ElixirForumHelpers.with_mixed_cassette("crit_6396_weighted_ordering", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "ElixirForum candidate ranks ahead of Reddit candidate (weight applied)", context do
        candidates = context.payload["candidates"] || []
        assert length(candidates) >= 2, "need >=1 candidate per source"

        [first | _] = candidates

        first_source = to_string(first["source"] || first[:source])

        assert first_source == "elixirforum",
               "expected ElixirForum candidate to rank first (weight 1.0 vs reddit 0.1); got first source: #{first_source}"

        {:ok, context}
      end
    end
  end
end
