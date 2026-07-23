defmodule MarketMySpecSpex.Story708.Criterion6151Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6151 — The agent lists venues, optionally filtered by source.

  The list_venues MCP tool returns all venues for the calling account when
  invoked without a source filter, and only venues matching the given source
  when filtered. The response payload is JSON-decoded from the tool's text
  content.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListVenues
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    text =
      Enum.map_join(parts, "\n", fn
        %{"text" => t} -> t
        %{text: t} -> t
        other -> inspect(other)
      end)

    Jason.decode!(text)
  end

  spex "the agent lists venues, optionally filtered by source" do
    scenario "list_venues with no filter returns every venue on the account" do
      given_ "an account with one Reddit and one ElixirForum venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})
        Fixtures.venue_fixture(scope, %{source: :elixirforum, identifier: "phoenix-forum"})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls list_venues with no source filter", context do
        {:reply, response, _frame} = ListVenues.execute(%{}, context.frame)
        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the payload includes both venues", context do
        venues = context.payload["venues"] || context.payload[:venues]
        assert is_list(venues), "expected list_venues payload to include a venues list"
        assert length(venues) >= 2

        sources = venues |> Enum.map(&(&1["source"] || &1[:source])) |> Enum.sort() |> Enum.uniq()
        assert "reddit" in sources or :reddit in sources
        assert "elixirforum" in sources or :elixirforum in sources

        {:ok, context}
      end
    end

    scenario "list_venues with source=reddit returns only reddit venues" do
      given_ "an account with one Reddit and one ElixirForum venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})
        Fixtures.venue_fixture(scope, %{source: :elixirforum, identifier: "phoenix-forum"})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls list_venues with source='reddit'", context do
        {:reply, response, _frame} = ListVenues.execute(%{source: "reddit"}, context.frame)
        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the payload includes only the reddit venue", context do
        venues = context.payload["venues"] || context.payload[:venues]
        assert is_list(venues)
        assert length(venues) == 1

        [venue] = venues
        assert (venue["source"] || venue[:source]) in ["reddit", :reddit]
        assert (venue["identifier"] || venue[:identifier]) == "elixir"

        {:ok, context}
      end
    end
  end
end
