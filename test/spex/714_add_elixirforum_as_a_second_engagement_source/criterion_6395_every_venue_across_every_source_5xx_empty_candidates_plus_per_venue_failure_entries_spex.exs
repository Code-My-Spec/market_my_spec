defmodule MarketMySpecSpex.Story714.Criterion6395Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6395 — Every venue across every source 5xx: empty
  candidates plus per-venue failure entries.

  Per-venue (NOT per-source) failure entries: two enabled Reddit
  venues + two enabled ElixirForum venues, all 5xx — failures list
  carries one entry per venue (4 total), each with the venue identifier.

  Test infrastructure: ReqCassette via `with_mixed_cassette/2`. The
  cassette captures four 5xx responses (one per venue).

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

  spex "all venues 5xx → empty candidates; per-venue failure entries (one per venue identifier)" do
    scenario "Four venues all 5xx → 4 failure entries with distinct identifiers" do
      given_ "four enabled venues (2 reddit + 2 elixirforum)", context do
        scope = Fixtures.account_scoped_user_fixture()
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        Fixtures.venue_fixture(scope, %{
          source: :reddit,
          identifier: "programming",
          enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :elixirforum,
          identifier: "phoenix-forum",
          enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :elixirforum,
          identifier: "questions-help",
          enabled: true
        })

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, resp, _} =
          ElixirForumHelpers.with_mixed_cassette("crit_6395_all_venues_5xx", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "candidates empty; failures has 4 entries with distinct venue identifiers", context do
        candidates = context.payload["candidates"] || []
        failures = context.payload["failures"] || []

        assert candidates == [], "expected empty candidates"

        identifiers =
          failures
          |> Enum.map(&(&1["venue_identifier"] || &1[:venue_identifier]))
          |> Enum.reject(&is_nil/1)
          |> Enum.sort()

        for expected <- ["elixir", "programming", "phoenix-forum", "questions-help"] do
          assert expected in identifiers,
                 "expected venue identifier #{expected} in failures; got: #{inspect(identifiers)}"
        end

        assert length(failures) == 4,
               "expected 1 failure entry per venue (4 total); got #{length(failures)}: #{inspect(failures)}"

        {:ok, context}
      end
    end
  end
end
