defmodule MarketMySpecSpex.Story733.Criterion6491Spex do
  @moduledoc """
  Story 733 — 6491. Reddit search dispatches through the user's
  online agent. SearchEngagements emits an http_request envelope on
  agents:<user_id>; the agent's reply populates the tool's response.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "reddit search dispatches through user's online agent" do
    scenario "tool dispatches via the agent and returns the agent's response" do
      given_ "a paired, online agent for a user with a reddit venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")
        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent.id, token)

        Fixtures.subscribe_to_agent_topic(user.id)
        frame = %{assigns: %{current_scope: scope}, context: %{session_id: "spec"}}
        {:ok, Map.merge(context, %{frame: frame})}
      end

      when_ "search_engagements is invoked for the reddit venue", context do
        caller = self()

        spawn_link(fn ->
          send(caller, {:tool_result, SearchEngagements.execute(%{query: "elixir"}, context.frame)})
        end)

        envelope = Fixtures.expect_http_request_envelope()

        Fixtures.respond_to_envelope(
          envelope,
          200,
          %{"content-type" => ["application/json"]},
          Jason.encode!(%{"kind" => "Listing", "data" => %{"children" => [], "after" => nil}})
        )

        result =
          receive do
            {:tool_result, r} -> r
          after
            5_000 -> flunk("tool did not return after agent response")
          end

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the tool returned via the agent transport (no direct HTTP)", context do
        {:reply, _response, _frame} = context.result
        {:ok, context}
      end
    end
  end
end
