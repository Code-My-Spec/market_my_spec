defmodule MarketMySpecSpex.Story744.Criterion6594Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6594 — Provider error mid-stream becomes a recoverable error state

  Rule R8 (failure path): a provider error (429/500) during streaming surfaces
  as a recoverable error state with a retry affordance, leaving the LiveView and
  other chats unaffected. The `:chat_llm` fixture fails the stream; the founder
  sees an error message with a retry button and a still-usable chat.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "a provider error becomes a retryable error state" do
    scenario "the provider returns 429 mid-stream" do
      given_ "a signed-in founder whose provider will error mid-stream", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{error: :rate_limited})

        {:ok, view, _html} = live(conn, "/chat")
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a message and the stream fails", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "draft something"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the assistant message enters an error state with a retry affordance", context do
        assert has_element?(context.view, "[data-test='message-error']")
        assert has_element?(context.view, "[data-test='retry-button']")
        refute has_element?(context.view, "[data-test='streaming-indicator']")
        :ok
      end

      then_ "the LiveView itself is unaffected and still usable", context do
        assert has_element?(context.view, "[data-test='chat-form']")
        assert has_element?(context.view, "[data-test='user-message']", "draft something")
        :ok
      end
    end
  end
end
