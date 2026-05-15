defmodule MarketMySpecSpex.Story708.Criterion6150Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6150 — The agent creates a venue via add_venue MCP tool.

  Drives the AddVenue tool's execute/2 callback with a Reddit and an
  ElixirForum payload. Asserts the response envelope shape and confirms the
  venue is persisted under the calling account.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements
  alias MarketMySpec.McpServers.Engagements.Tools.AddVenue
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  spex "the agent creates a venue via add_venue MCP tool" do
    scenario "add_venue persists a Reddit venue scoped to the account" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls add_venue with source=reddit, identifier=elixir", context do
        result = AddVenue.execute(%{source: "reddit", identifier: "elixir"}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns {:reply, %Response{}, frame} and the venue is in the DB",
            context do
        assert {:reply, %Response{}, _frame} = context.result

        venues = Engagements.list_venues(context.scope, :reddit)
        assert Enum.any?(venues, &(&1.identifier == "elixir")),
               "expected reddit/elixir venue to be persisted on the account"

        {:ok, context}
      end
    end

    scenario "add_venue persists an ElixirForum venue scoped to the account" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls add_venue with source=elixirforum", context do
        result =
          AddVenue.execute(
            %{source: "elixirforum", identifier: "phoenix-forum"},
            context.frame
          )

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns {:reply, %Response{}, frame} and the venue is in the DB",
            context do
        assert {:reply, %Response{}, _frame} = context.result

        venues = Engagements.list_venues(context.scope, :elixirforum)
        assert Enum.any?(venues, &(&1.identifier == "phoenix-forum")),
               "expected elixirforum/phoenix-forum venue to be persisted"

        {:ok, context}
      end
    end
  end
end
