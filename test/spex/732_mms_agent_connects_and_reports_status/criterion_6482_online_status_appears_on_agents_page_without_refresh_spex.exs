defmodule MarketMySpecSpex.Story732.Criterion6482Spex do
  @moduledoc """
  Story 732 — 6482. Online status appears on the Agents page without
  refresh when the binary joins.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "online status appears on Agents page without refresh" do
    scenario "joining the channel after the page is mounted flips the indicator" do
      given_ "a paired agent and the Agents page already mounted", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")

        {:ok, view, html0} = live(conn, "/agents")
        refute html0 =~ ~s|data-test="status-online-#{agent.id}"|

        {:ok, Map.merge(context, %{user: user, agent: agent, token: token, view: view})}
      end

      when_ "the binary joins its user's channel", context do
        {:ok, _reply, _socket} =
          Fixtures.join_agent_channel(context.user.id, context.agent.id, context.token)

        {:ok, context}
      end

      then_ "the Agents page flips the agent to online without a refresh", context do
        Process.sleep(100)
        html = render(context.view)
        assert html =~ ~s|data-test="status-online-#{context.agent.id}"|
        {:ok, context}
      end
    end
  end
end
