defmodule MarketMySpecSpex.Story744.ChatIndexNavigationSpex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI (enhancement)
  Chats index/menu — list the account's chats and navigate back to old ones.

  The header carries a chats menu listing the account's conversations (titled
  from their first message); clicking one switches the active chat to it and
  loads that conversation's messages.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the chats menu lists chats and navigates to old ones" do
    scenario "two chats exist; open the older one from the menu" do
      given_ "a signed-in founder who has had two separate chats", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["ok"], finish_reason: "stop"})

        {:ok, view, _html} = live(conn, "/app/chat")

        # First chat (the auto-created active conversation).
        view
        |> form("[data-test='chat-form']", message: %{content: "alpha question"})
        |> render_submit()

        # Start a second, separate chat and send in it.
        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "marketing_strategy"})
        |> render_submit()

        view
        |> form("[data-test='chat-form']", message: %{content: "beta question"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      then_ "the chats menu lists both chats", context do
        assert has_element?(context.view, "[data-test='chats-menu']")
        assert has_element?(context.view, "[data-test='chat-list-item']", "alpha question")
        assert has_element?(context.view, "[data-test='chat-list-item']", "beta question")
        {:ok, context}
      end

      when_ "the founder opens the older chat from the menu", context do
        context.view
        |> element("[data-test='chat-list-item']", "alpha question")
        |> render_click()

        {:ok, context}
      end

      then_ "the older chat's messages load and the other chat's do not", context do
        assert has_element?(context.view, "[data-test='user-message']", "alpha question")
        refute has_element?(context.view, "[data-test='user-message']", "beta question")
        {:ok, context}
      end
    end
  end
end
