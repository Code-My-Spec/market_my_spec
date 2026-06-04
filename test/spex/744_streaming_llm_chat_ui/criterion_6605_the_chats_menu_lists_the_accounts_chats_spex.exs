defmodule MarketMySpecSpex.Story744.Criterion6605Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6605 — The chats index lists the account's chats

  Rule: the chats index lists the account's chats and lets the founder open an
  old one. With two separate chats in the account, the index table lists both,
  each labelled by its first message.

  Interaction surface: LiveView (chats index `MarketMySpecWeb.ChatLive.Index` at
  "/app/chats").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the chats index lists the account's chats" do
    scenario "two separate chats both appear in the index" do
      given_ "a signed-in founder who has had two separate chats", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["ok"], finish_reason: "stop"})

        alpha = start_chat(conn, :problem_discovery)

        alpha
        |> form("[data-test='chat-form']", message: %{content: "alpha question"})
        |> render_submit()

        beta = start_chat(conn, :marketing_strategy)

        beta
        |> form("[data-test='chat-form']", message: %{content: "beta question"})
        |> render_submit()

        {:ok, index, _html} = live(conn, "/app/chats")
        {:ok, Map.merge(context, %{conn: conn, view: index})}
      end

      then_ "the index table lists both chats, labelled by their first message", context do
        assert has_element?(context.view, "[data-test='chats-table']")
        assert has_element?(context.view, "[data-test='chat-list-item']", "alpha question")
        assert has_element?(context.view, "[data-test='chat-list-item']", "beta question")
        {:ok, context}
      end
    end
  end
end
