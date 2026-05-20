defmodule MarketMySpecSpex.Story732.Criterion6489Spex do
  @moduledoc """
  Story 732 — 6489. Disconnecting one of a user's agents must not
  flip the other agents' online indicator off.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "disconnect of one agent keeps other agents online" do
    scenario "two paired+online agents; killing one leaves the other online" do
      given_ "a user with two paired+joined agents and /agents mounted", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})

        {agent_a, token_a} = Fixtures.pair_via_ui(conn, user, name: "box-a")
        {agent_b, token_b} = Fixtures.pair_via_ui(conn, user, name: "box-b")

        {:ok, _, ch_a} = Fixtures.join_agent_channel(user.id, agent_a.id, token_a)
        {:ok, _, _ch_b} = Fixtures.join_agent_channel(user.id, agent_b.id, token_b)

        {:ok, view, _} = live(conn, "/agents")
        {:ok, Map.merge(context, %{view: view, ch_a: ch_a, agent_a: agent_a, agent_b: agent_b})}
      end

      when_ "agent A disconnects", context do
        :ok = Fixtures.kill_channel(context.ch_a)
        {:ok, context}
      end

      then_ "agent B remains online on the Agents page", context do
        Process.sleep(100)
        html = render(context.view)
        assert html =~ "box-b"
        assert html =~ ~s|data-test="status-online-#{context.agent_b.id}"|
        {:ok, context}
      end
    end
  end
end
