defmodule MarketMySpecSpex.Story733.Criterion6494Spex do
  @moduledoc """
  Story 733 — 6494. Non-allowlisted host is refused before dispatch.

  The surface for "ask the agent to do an HTTP request" is
  `MarketMySpec.Agents.Dispatcher.dispatch_http/3` — callers within
  MMS trust it to enforce the allowlist. The spec drives that
  contract via a Fixtures wrapper and asserts no broadcast emitted.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "non-allowlisted host is refused before dispatch" do
    scenario "dispatch_http for example.com returns host_not_allowed and emits nothing" do
      given_ "an authenticated user subscribed to the agents topic", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        Fixtures.subscribe_to_agent_topic(user.id)
        {:ok, Map.put(context, :user, user)}
      end

      when_ "Dispatcher is called with a non-allowlisted URL", context do
        result =
          Fixtures.dispatch_http(context.user, %{
            method: :get,
            url: "https://example.com/not-reddit",
            headers: [],
            body: ""
          })

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the result is {:error, :host_not_allowed}", context do
        assert context.result == {:error, :host_not_allowed}
        {:ok, context}
      end

      then_ "no http_request broadcast was emitted", context do
        assert Fixtures.receive_http_request_envelope(200) == :no_broadcast
        {:ok, context}
      end
    end
  end
end
