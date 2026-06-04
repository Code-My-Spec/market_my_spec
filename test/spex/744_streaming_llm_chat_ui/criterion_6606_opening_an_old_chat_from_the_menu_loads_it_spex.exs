defmodule MarketMySpecSpex.Story744.Criterion6606Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6606 — Opening an old chat from the menu loads it

  Rule: the chat header lists the account's chats and lets the founder open an
  old one. With a newer chat active, clicking an older chat in the menu makes
  it the active chat and loads its messages; the other chat's messages are no
  longer shown.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "opening an older chat from the menu loads it" do
    scenario "click the older chat while a newer one is active" do
      given_ "a signed-in founder with an older chat and a newer active chat", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["ok"], finish_reason: "stop"})

        {:ok, view, _html} = live(conn, "/app/chat")

        # Older chat.
        view
        |> form("[data-test='chat-form']", message: %{content: "alpha question"})
        |> render_submit()

        # Newer chat — now the active one.
        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "marketing_strategy"})
        |> render_submit()

        view
        |> form("[data-test='chat-form']", message: %{content: "beta question"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder clicks the older chat in the menu", context do
        context.view
        |> element("[data-test='chat-list-item']", "alpha question")
        |> render_click()

        {:ok, context}
      end

      then_ "the older chat becomes active and its messages load", context do
        assert has_element?(context.view, "[data-test='user-message']", "alpha question")
        {:ok, context}
      end

      then_ "the newer chat's messages are no longer shown", context do
        refute has_element?(context.view, "[data-test='user-message']", "beta question")
        {:ok, context}
      end
    end
  end
end
