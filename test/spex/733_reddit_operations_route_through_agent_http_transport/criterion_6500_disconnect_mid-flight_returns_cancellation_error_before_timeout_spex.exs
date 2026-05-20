defmodule MarketMySpecSpex.Story733.Criterion6500Spex do
  @moduledoc """
  Story 733 — 6500. If the agent disconnects mid-flight, Dispatcher
  returns `{:error, :agent_disconnected}` well before the 30s deadline.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "disconnect mid-flight returns cancellation before timeout" do
    scenario "agent disconnects while dispatcher is waiting; result is :agent_disconnected" do
      given_ "a paired, online agent ready to receive a request", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")
        {:ok, _, channel} = Fixtures.join_agent_channel(user.id, agent.id, token)
        Fixtures.subscribe_to_agent_topic(user.id)
        {:ok, Map.merge(context, %{user: user, channel: channel})}
      end

      when_ "dispatcher is called; agent disconnects before responding", context do
        user = context.user
        channel = context.channel

        task =
          Task.async(fn ->
            Fixtures.dispatch_http(user, %{
              method: :get,
              url: "https://oauth.reddit.com/r/elixir.json",
              headers: [],
              body: ""
            })
          end)

        _envelope = Fixtures.expect_http_request_envelope()

        {time, _} =
          :timer.tc(fn ->
            Fixtures.kill_channel(channel)
          end)

        result = Task.await(task, 5_000)

        {:ok, Map.merge(context, %{result: result, elapsed_us: time})}
      end

      then_ "result is :agent_disconnected and returns in well under 30 seconds", context do
        assert context.result == {:error, :agent_disconnected}
        assert context.elapsed_us < 10_000_000
        {:ok, context}
      end
    end
  end
end
