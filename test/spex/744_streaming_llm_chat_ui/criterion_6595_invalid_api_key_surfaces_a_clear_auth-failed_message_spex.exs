defmodule MarketMySpecSpex.Story744.Criterion6595Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6595 — Invalid API key surfaces a clear auth-failed message

  Rule R8 (failure path): when the configured provider API key is invalid, the
  founder sees a clear "provider auth failed" message and the page does not
  crash. The `:chat_llm` fixture fails with an auth error; the chat surface
  stays alive and explains what went wrong.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "an invalid API key produces a clear auth-failed message" do
    scenario "the provider rejects the request for bad credentials" do
      given_ "a signed-in founder whose provider key is invalid", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{error: :invalid_api_key})

        {:ok, view, _html} = live(conn, "/app/chat")
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a message", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "hello"})
        |> render_submit()

        {:ok, context}
      end

      then_ "a clear provider-auth-failed message is shown", context do
        assert has_element?(context.view, "[data-test='message-error']")
        assert render(context.view) =~ "provider auth failed"
        {:ok, context}
      end

      then_ "the page did not crash — the chat is still rendered", context do
        assert has_element?(context.view, "[data-test='chat-form']")
        {:ok, context}
      end
    end
  end
end
