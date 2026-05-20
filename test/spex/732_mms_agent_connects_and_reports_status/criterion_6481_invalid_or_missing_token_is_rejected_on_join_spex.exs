defmodule MarketMySpecSpex.Story732.Criterion6481Spex do
  @moduledoc """
  Story 732 — 6481. Invalid or missing token is rejected on join.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "invalid or missing token is rejected on join" do
    scenario "a join with a bogus token is refused" do
      given_ "a paired user (only their token would be valid)", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, _real_token} = Fixtures.pair_via_ui(conn, user, name: "mac-mini")
        {:ok, Map.merge(context, %{user: user, agent: agent})}
      end

      when_ "an attacker joins with a bogus token", context do
        result =
          Fixtures.join_agent_channel(context.user.id, context.agent.id, "not-a-real-token")

        {:ok, Map.put(context, :bogus_join, result)}
      end

      then_ "the bogus join is refused", context do
        assert {:error, _reason} = context.bogus_join
        {:ok, context}
      end
    end

    scenario "a join with no token at all is refused" do
      given_ "an authenticated user with no agent", context do
        user = Fixtures.user_fixture()
        {:ok, Map.put(context, :user, user)}
      end

      when_ "a join is attempted without a token param", context do
        result = Fixtures.join_agent_channel(context.user.id, "any", "")
        {:ok, Map.put(context, :no_tok_join, result)}
      end

      then_ "the join is refused", context do
        assert {:error, _reason} = context.no_tok_join
        {:ok, context}
      end
    end
  end
end
