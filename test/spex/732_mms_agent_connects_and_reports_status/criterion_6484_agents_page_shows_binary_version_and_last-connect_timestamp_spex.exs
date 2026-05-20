defmodule MarketMySpecSpex.Story732.Criterion6484Spex do
  @moduledoc """
  Story 732 — 6484. Agents page shows binary version and last-connect
  timestamp after a join with self-reported version.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "Agents page shows binary version and last-connect timestamp" do
    scenario "joined agent renders its self-reported version and a last-connect value" do
      given_ "a paired agent that has joined with version 0.3.0", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac-v")

        {:ok, _reply, _channel} =
          Fixtures.join_agent_channel(user.id, agent.id, token, version: "0.3.0")

        {:ok, Map.put(context, :conn, conn)}
      end

      when_ "the user visits /agents", context do
        {:ok, _view, html} = live(context.conn, "/agents")
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the agent's binary version renders", context do
        assert context.html =~ "0.3.0"
        {:ok, context}
      end

      then_ "a last-connect timestamp renders", context do
        assert context.html =~ ~r/\d{4}-\d{2}-\d{2}|ago|just now/i
        {:ok, context}
      end
    end
  end
end
