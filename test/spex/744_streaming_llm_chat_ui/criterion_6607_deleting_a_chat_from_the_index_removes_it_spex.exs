defmodule MarketMySpecSpex.Story744.Criterion6607Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6607 — Deleting a chat from the index removes it and its messages

  Rule: the chats index lists the account's chats and lets the founder manage
  them. Deleting a chat from the index removes it from the table and tears down
  its messages, so it no longer appears and cannot be reopened.

  Interaction surface: LiveView (chats index `MarketMySpecWeb.ChatLive.Index` at
  "/app/chats").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Chat
  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "deleting a chat from the index removes it" do
    scenario "delete one of two chats" do
      given_ "a signed-in founder with two chats in the index", context do
        user = Fixtures.user_fixture()
        scope = Fixtures.user_scope_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["ok"], finish_reason: "stop"})

        doomed = start_chat(conn, :problem_discovery)

        doomed
        |> form("[data-test='chat-form']", message: %{content: "delete me"})
        |> render_submit()

        doomed_id = chat_id(doomed)

        kept = start_chat(conn, :marketing_strategy)

        kept
        |> form("[data-test='chat-form']", message: %{content: "keep me"})
        |> render_submit()

        {:ok, index, _html} = live(conn, "/app/chats")
        {:ok, Map.merge(context, %{conn: conn, scope: scope, index: index, doomed_id: doomed_id})}
      end

      when_ "the founder deletes the first chat from the index", context do
        context.index
        |> element("[data-test='delete-chat-#{context.doomed_id}']")
        |> render_click()

        {:ok, context}
      end

      then_ "the deleted chat is gone from the index and the other remains", context do
        refute has_element?(context.index, "[data-test='chat-list-item']", "delete me")
        assert has_element?(context.index, "[data-test='chat-list-item']", "keep me")
        {:ok, context}
      end

      then_ "the conversation no longer exists for the account", context do
        assert Chat.get_conversation(context.scope, context.doomed_id) == nil
        {:ok, context}
      end
    end
  end
end
