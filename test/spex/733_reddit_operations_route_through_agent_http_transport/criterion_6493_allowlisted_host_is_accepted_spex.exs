defmodule MarketMySpecSpex.Story733.Criterion6493Spex do
  @moduledoc """
  Story 733 — 6493. Allowlisted host (reddit.com) is accepted; an
  http_request envelope is broadcast targeting a reddit host.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "allowlisted host is accepted" do
    scenario "reddit search emits an http_request envelope targeting reddit.com" do
      given_ "a paired, online agent and a reddit venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")
        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent.id, token)
        Fixtures.subscribe_to_agent_topic(user.id)

        frame = %{assigns: %{current_scope: scope}, context: %{session_id: "spec"}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "search_engagements is invoked", context do
        spawn_link(fn -> SearchEngagements.execute(%{query: "elixir"}, context.frame) end)
        {:ok, context}
      end

      then_ "an http_request envelope to a reddit host is broadcast", context do
        env = Fixtures.expect_http_request_envelope(2_000)
        url = env["url"] || env[:url]
        assert is_binary(url) and url =~ ~r/(\.|^)reddit\.com/
        {:ok, Map.put(context, :env, env)}
      end
    end
  end
end
