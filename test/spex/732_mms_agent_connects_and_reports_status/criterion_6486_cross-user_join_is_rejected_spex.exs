defmodule MarketMySpecSpex.Story732.Criterion6486Spex do
  @moduledoc """
  Story 732 — 6486. Cross-user join is rejected.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "cross-user join is rejected" do
    scenario "user A's token cannot join agents:<user_b_id>" do
      given_ "user A with a paired agent, plus a second user B", context do
        user_a = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user_a)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent_a, token_a} = Fixtures.pair_via_ui(conn, user_a, name: "mac-a")

        user_b = Fixtures.user_fixture()
        {:ok, Map.merge(context, %{agent_a: agent_a, token_a: token_a, user_b: user_b})}
      end

      when_ "agent A tries to join agents:<user_b_id> with its own token", context do
        result =
          Fixtures.join_agent_channel(context.user_b.id, context.agent_a.id, context.token_a)

        {:ok, Map.put(context, :cross_join, result)}
      end

      then_ "the join is refused", context do
        assert {:error, _reason} = context.cross_join
        {:ok, context}
      end
    end
  end
end
