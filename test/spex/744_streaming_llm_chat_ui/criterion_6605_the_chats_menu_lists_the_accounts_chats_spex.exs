defmodule MarketMySpecSpex.Story744.Criterion6605Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6605 — The chats menu lists the account's chats

  Rule: the chat header lists the account's chats and lets the founder open an
  old one. With two separate chats in the account, the header's chats menu
  lists both, each labelled by its first message.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the chats menu lists the account's chats" do
    scenario "two separate chats both appear in the menu" do
      given_ "a signed-in founder who has had two separate chats", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["ok"], finish_reason: "stop"})

        {:ok, view, _html} = live(conn, "/app/chat")

        view
        |> form("[data-test='chat-form']", message: %{content: "alpha question"})
        |> render_submit()

        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "marketing_strategy"})
        |> render_submit()

        view
        |> form("[data-test='chat-form']", message: %{content: "beta question"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      then_ "the chats menu lists both chats, labelled by their first message", context do
        assert has_element?(context.view, "[data-test='chats-menu']")
        assert has_element?(context.view, "[data-test='chat-list-item']", "alpha question")
        assert has_element?(context.view, "[data-test='chat-list-item']", "beta question")
        {:ok, context}
      end
    end
  end
end
