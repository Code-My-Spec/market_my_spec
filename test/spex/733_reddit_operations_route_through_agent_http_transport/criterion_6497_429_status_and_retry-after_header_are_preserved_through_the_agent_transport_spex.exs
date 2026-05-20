defmodule MarketMySpecSpex.Story733.Criterion6497Spex do
  @moduledoc """
  Story 733 — 6497. A 429 status and the Retry-After header from
  Reddit must be preserved through the agent transport.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "429 status and Retry-After header are preserved" do
    scenario "agent answers with 429+Retry-After; dispatcher surfaces both" do
      given_ "a paired, online agent", context do
        scope = Fixtures.account_scoped_user_fixture()
        user = scope.user
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {agent, token} = Fixtures.pair_via_ui(conn, user, name: "mac")
        {:ok, _, _} = Fixtures.join_agent_channel(user.id, agent.id, token)
        Fixtures.subscribe_to_agent_topic(user.id)

        {:ok, Map.put(context, :user, user)}
      end

      when_ "dispatcher is called and agent answers with 429+Retry-After", context do
        caller = self()

        spawn_link(fn ->
          send(caller, {:dispatch, Fixtures.dispatch_http(context.user, %{
            method: :get,
            url: "https://oauth.reddit.com/r/elixir/new.json",
            headers: [],
            body: ""
          })})
        end)

        envelope = Fixtures.expect_http_request_envelope()
        Fixtures.respond_to_envelope(envelope, 429, %{"retry-after" => ["60"]}, "")

        result =
          receive do
            {:dispatch, r} -> r
          after
            5_000 -> flunk("dispatcher did not return")
          end

        {:ok, Map.put(context, :result, result)}
      end

      then_ "status 429 and Retry-After header are both present", context do
        assert {:ok, %{status: 429, headers: headers}} = context.result

        retry_after =
          cond do
            is_map(headers) ->
              Map.get(headers, "retry-after") || Map.get(headers, "Retry-After")

            is_list(headers) ->
              Enum.find_value(headers, fn
                {k, v} when is_binary(k) ->
                  if String.downcase(k) == "retry-after", do: v
                _ -> nil
              end)
          end

        assert retry_after in ["60", ["60"]]
        {:ok, context}
      end
    end
  end
end
