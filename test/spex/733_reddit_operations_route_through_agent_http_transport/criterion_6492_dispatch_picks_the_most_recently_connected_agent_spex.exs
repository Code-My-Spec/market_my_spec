defmodule MarketMySpecSpex.Story733.Criterion6492Spex do
  @moduledoc """
  Story 733 — 6492. When a user has two online agents, Dispatcher
  must target the most-recently-connected one.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "dispatch picks the most recently connected agent" do
    scenario "two agents online; the newer one receives the http_request envelope" do
      given_ "a user with two paired+joined agents (agent_b joined last)", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})

        {agent_a, token_a} = Fixtures.pair_via_ui(conn, user, name: "agent-a")
        {agent_b, token_b} = Fixtures.pair_via_ui(conn, user, name: "agent-b")

        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent_a.id, token_a)
        # ensure agent_b's online_at is strictly later than agent_a's
        Process.sleep(1_100)
        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent_b.id, token_b)

        Fixtures.subscribe_to_agent_topic(user.id)
        frame = %{assigns: %{current_scope: scope}, context: %{session_id: "spec"}}
        {:ok, Map.merge(context, %{agent_b: agent_b, frame: frame})}
      end

      when_ "search_engagements is invoked", context do
        spawn_link(fn -> SearchEngagements.execute(%{query: "elixir"}, context.frame) end)
        {:ok, context}
      end

      then_ "the http_request envelope targets agent_b (most recently connected)", context do
        envelope = Fixtures.expect_http_request_envelope(3_000)
        assert envelope["agent_id"] == context.agent_b.id
        {:ok, Map.put(context, :envelope, envelope)}
      end
    end
  end
end
