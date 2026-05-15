defmodule MarketMySpecSpex.Story708.Criterion6138Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6138 — LLM can call `add_venue`, `list_venues` (optionally filtered by
  source), `update_venue`, and `remove_venue` MCP tools.

  The engagement MCP server exposes four venue management tools registered on
  `MarketMySpec.McpServers.MarketingStrategyServer`. Each tool exposes the
  Anubis component contract (`execute/2` returning `{:reply, %Response{}, frame}`).

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.AddVenue
  alias MarketMySpec.McpServers.Engagements.Tools.ListVenues
  alias MarketMySpec.McpServers.Engagements.Tools.RemoveVenue
  alias MarketMySpec.McpServers.Engagements.Tools.UpdateVenue
  alias MarketMySpec.McpServers.MarketingStrategyServer
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  spex "LLM can call add_venue, list_venues, update_venue, and remove_venue MCP tools" do
    scenario "all four venue tools are registered on the marketing-strategy MCP server" do
      given_ "the marketing-strategy server's tool list", context do
        names = MarketingStrategyServer.__components__(:tool) |> Enum.map(& &1.name)
        {:ok, Map.put(context, :tool_names, names)}
      end

      then_ "add_venue, list_venues, update_venue, and remove_venue all appear",
            context do
        for name <- ~w(add_venue list_venues update_venue remove_venue) do
          assert name in context.tool_names,
                 "expected #{name} on MarketingStrategyServer; got: #{inspect(context.tool_names)}"
        end

        {:ok, context}
      end
    end

    scenario "add_venue returns a reply tuple with a Response struct" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the LLM calls add_venue with a valid reddit venue", context do
        result = AddVenue.execute(%{source: "reddit", identifier: "elixir"}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the tool returns {:reply, %Response{}, frame}", context do
        assert {:reply, %Response{}, _frame} = context.result
        {:ok, context}
      end
    end

    scenario "list_venues returns a reply tuple with a Response struct" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the LLM calls list_venues with no filter", context do
        result = ListVenues.execute(%{}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the tool returns {:reply, %Response{}, frame}", context do
        assert {:reply, %Response{}, _frame} = context.result
        {:ok, context}
      end
    end

    scenario "update_venue returns a reply tuple with a Response struct" do
      given_ "an authenticated account-scoped user with one venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope), venue_id: venue.id})}
      end

      when_ "the LLM calls update_venue with enabled: false", context do
        result =
          UpdateVenue.execute(
            %{venue_id: context.venue_id, enabled: false},
            context.frame
          )

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the tool returns {:reply, %Response{}, frame}", context do
        assert {:reply, %Response{}, _frame} = context.result
        {:ok, context}
      end
    end

    scenario "remove_venue returns a reply tuple with a Response struct" do
      given_ "an authenticated account-scoped user with one venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope), venue_id: venue.id})}
      end

      when_ "the LLM calls remove_venue with the venue id", context do
        result = RemoveVenue.execute(%{venue_id: context.venue_id}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the tool returns {:reply, %Response{}, frame}", context do
        assert {:reply, %Response{}, _frame} = context.result
        {:ok, context}
      end
    end
  end
end
