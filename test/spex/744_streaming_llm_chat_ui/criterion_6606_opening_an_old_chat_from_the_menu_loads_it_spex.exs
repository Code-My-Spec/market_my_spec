defmodule MarketMySpecSpex.Story744.Criterion6606Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6606 — Opening an old chat from the index loads it

  Rule: the chats index lists the account's chats and lets the founder open an
  old one. With a newer chat also present, clicking an older chat in the index
  opens it and loads its messages; the other chat's messages are not shown.

  Interaction surface: LiveView (chats index `MarketMySpecWeb.ChatLive.Index` at
  "/app/chats" → `MarketMySpecWeb.ChatLive.Show` at "/app/chats/:id").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "opening an older chat from the index loads it" do
    scenario "click the older chat from the index" do
      given_ "a signed-in founder with an older chat and a newer chat", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["ok"], finish_reason: "stop"})

        # Older chat.
        older = start_chat(conn, :problem_discovery)

        older
        |> form("[data-test='chat-form']", message: %{content: "alpha question"})
        |> render_submit()

        # Newer chat.
        newer = start_chat(conn, :marketing_strategy)

        newer
        |> form("[data-test='chat-form']", message: %{content: "beta question"})
        |> render_submit()

        {:ok, index, _html} = live(conn, "/app/chats")
        {:ok, Map.merge(context, %{conn: conn, index: index})}
      end

      when_ "the founder clicks the older chat in the index", context do
        {:error, {:live_redirect, %{to: path}}} =
          context.index
          |> element("[data-test='chat-row']", "alpha question")
          |> render_click()

        {:ok, show, _html} = live(context.conn, path)
        {:ok, Map.put(context, :view, show)}
      end

      then_ "the older chat opens and its messages load", context do
        assert has_element?(context.view, "[data-test='user-message']", "alpha question")
        {:ok, context}
      end

      then_ "the newer chat's messages are not shown", context do
        refute has_element?(context.view, "[data-test='user-message']", "beta question")
        {:ok, context}
      end
    end
  end
end
