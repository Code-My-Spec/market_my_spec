defmodule MarketMySpecSpex.Story733.Criterion6495Spex do
  @moduledoc """
  Story 733 — 6495. A response received within the 30-second deadline
  is returned to the caller.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "response within 30s is returned to the caller" do
    scenario "agent responds quickly; dispatcher returns the response" do
      given_ "a paired, online agent for a user", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")
        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent.id, token)
        Fixtures.subscribe_to_agent_topic(user.id)

        {:ok, Map.put(context, :user, user)}
      end

      when_ "Dispatcher is called and the agent answers quickly", context do
        caller = self()

        spawn_link(fn ->
          send(caller, {:dispatch, Fixtures.dispatch_http(context.user, %{
            method: :get,
            url: "https://oauth.reddit.com/r/elixir/about.json",
            headers: [],
            body: ""
          })})
        end)

        envelope = Fixtures.expect_http_request_envelope()
        Fixtures.respond_to_envelope(envelope, 200, %{}, "{}")

        result =
          receive do
            {:dispatch, r} -> r
          after
            5_000 -> flunk("dispatcher did not return")
          end

        {:ok, Map.put(context, :result, result)}
      end

      then_ "Dispatcher returns {:ok, %{status: 200, ...}}", context do
        assert {:ok, %{status: 200}} = context.result
        {:ok, context}
      end
    end
  end
end
