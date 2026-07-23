defmodule MarketMySpecSpex.Story732.Criterion6487Spex do
  @moduledoc """
  Story 732 — 6487. Revoked token is refused on rejoin.
  Revocation is driven through the /agents page UI.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "revoked token is refused on rejoin" do
    scenario "agent is revoked via the Agents page; rejoin with old token fails" do
      given_ "a paired agent and its issued token", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac-r")
        {:ok, Map.merge(context, %{user: user, agent: agent, token: token, conn: conn})}
      end

      when_ "the user revokes the agent via /agents", context do
        :ok = Fixtures.revoke_via_agents_page(context.conn, context.agent.id)
        {:ok, context}
      end

      when_ "the binary tries to rejoin with the old token", context do
        result = Fixtures.join_agent_channel(context.user.id, context.agent.id, context.token)
        {:ok, Map.put(context, :rejoin, result)}
      end

      then_ "the rejoin is refused", context do
        assert {:error, _reason} = context.rejoin
        {:ok, context}
      end
    end
  end
end
