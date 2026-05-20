defmodule MarketMySpecSpex.Story732.Criterion6480Spex do
  @moduledoc """
  Story 732 — 6480. Valid bearer token (issued by the pairing flow)
  joins the agents channel for its user.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "valid bearer token joins the agents channel" do
    scenario "a freshly paired agent joins its user's topic and is accepted" do
      given_ "a user who just paired an agent via the UI", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac-mini")

        {:ok, Map.merge(context, %{user: user, agent: agent, token: token})}
      end

      when_ "the binary joins agents:<user_id> with the issued token", context do
        result = Fixtures.join_agent_channel(context.user.id, context.agent.id, context.token)
        {:ok, Map.put(context, :join, result)}
      end

      then_ "the join reply is :ok", context do
        assert {:ok, _reply, _socket} = context.join
        {:ok, context}
      end
    end
  end
end
