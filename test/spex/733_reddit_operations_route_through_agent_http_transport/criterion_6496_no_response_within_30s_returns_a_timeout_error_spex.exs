defmodule MarketMySpecSpex.Story733.Criterion6496Spex do
  @moduledoc """
  Story 733 — 6496. No response within the deadline returns
  `{:error, :timeout}`. Uses a 100ms timeout via the opts param so
  the test doesn't actually wait 30s.
  """
  use MarketMySpecSpex.Case
  import Phoenix.ChannelTest

  alias MarketMySpec.Agents.Dispatcher
  alias MarketMySpecSpex.Fixtures

  spex "no response within deadline returns timeout error" do
    scenario "agent does not answer; dispatcher returns timeout" do
      given_ "a paired, online (but silent) agent", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user

        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})

        {:ok, v, _} =
          live(conn, "/agents/pair?state=to-#{System.unique_integer([:positive])}&port=51234&name=mac")

        v |> element("[data-test='approve-pairing']") |> render_click()
        {url, _} = assert_redirect(v)
        %URI{query: q} = URI.parse(url)
        token = URI.decode_query(q || "") |> Map.fetch!("token")
        [agent] = Fixtures.list_paired_agents(user.id)

        {:ok, _, _} =
          MarketMySpecWeb.AgentSocket
          |> socket("agent:#{agent.id}", %{})
          |> subscribe_and_join(MarketMySpecWeb.AgentChannel, "agents:#{user.id}", %{
            "agent_id" => agent.id,
            "token" => token
          })

        {:ok, Map.put(context, :user, user)}
      end

      when_ "Dispatcher.dispatch_http is called with a short timeout and no answer comes", context do
        result =
          Dispatcher.dispatch_http(
            context.user,
            %{method: :get, url: "https://oauth.reddit.com/r/elixir.json", headers: [], body: ""},
            timeout: 100
          )

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dispatcher returns {:error, :timeout}", context do
        assert context.result == {:error, :timeout}
        {:ok, context}
      end
    end
  end
end
