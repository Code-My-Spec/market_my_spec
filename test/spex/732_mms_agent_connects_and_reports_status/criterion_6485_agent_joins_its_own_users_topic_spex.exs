defmodule MarketMySpecSpex.Story732.Criterion6485Spex do
  @moduledoc """
  Story 732 — 6485. Agent joins its own user's topic.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "agent joins its own user's topic" do
    scenario "join under agents:<owner_user_id> is accepted" do
      given_ "a paired agent for user A", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")
        {:ok, Map.merge(context, %{user: user, agent: agent, token: token})}
      end

      when_ "the agent joins agents:<user_a_id>", context do
        result = Fixtures.join_agent_channel(context.user.id, context.agent.id, context.token)
        {:ok, Map.put(context, :join, result)}
      end

      then_ "the join is accepted", context do
        assert {:ok, _reply, _socket} = context.join
        {:ok, context}
      end
    end
  end
end
