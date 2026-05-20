defmodule MarketMySpecSpex.Story732.Criterion6488Spex do
  @moduledoc """
  Story 732 — 6488. A failed join attempt must not flip an agent's
  status to online on the Agents page.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "failed join attempt does not flip status to online" do
    scenario "join with a bad token leaves the page showing offline" do
      given_ "a paired agent and the Agents page mounted", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, _token} = Fixtures.pair_via_ui(conn, user, name: "mac-fj")

        {:ok, view, _} = live(conn, "/agents")
        {:ok, Map.merge(context, %{user: user, agent: agent, view: view})}
      end

      when_ "a join is attempted with a bad token", context do
        _ = Fixtures.join_agent_channel(context.user.id, context.agent.id, "nope")
        {:ok, context}
      end

      then_ "the Agents page still shows the agent as offline", context do
        html = render(context.view)
        refute html =~ ~s|data-test="status-online-#{context.agent.id}"|
        {:ok, context}
      end
    end
  end
end
