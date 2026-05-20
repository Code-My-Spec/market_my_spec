defmodule MarketMySpecSpex.Story732.Criterion6483Spex do
  @moduledoc """
  Story 732 — 6483. Offline status appears on the Agents page
  without refresh when the agent's channel disconnects.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "offline status appears on Agents page without refresh" do
    scenario "agent disconnect flips the indicator from online to offline" do
      given_ "a paired and online agent with the Agents page mounted", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")

        {:ok, _reply, channel} = Fixtures.join_agent_channel(user.id, agent.id, token)
        {:ok, view, _} = live(conn, "/agents")
        {:ok, Map.merge(context, %{view: view, channel: channel, agent: agent})}
      end

      when_ "the binary disconnects", context do
        :ok = Fixtures.kill_channel(context.channel)
        {:ok, context}
      end

      then_ "the Agents page flips the indicator to offline without a refresh", context do
        Process.sleep(100)
        html = render(context.view)
        refute html =~ ~s|data-test="status-online-#{context.agent.id}"|
        assert html =~ "Offline"
        {:ok, context}
      end
    end
  end
end
