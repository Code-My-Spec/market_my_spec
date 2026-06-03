defmodule MarketMySpecSpex.Story744.Criterion6587Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6587 — Partial stream is restored after mid-stream reload

  Rule R4: a reconnecting / reloading LiveView restores in-flight streaming
  state. With a reply mid-stream (the `:chat_llm` fixture emits a chunk then
  hangs), the partial assistant text and the in-progress indicator live in
  ActiveTasks; a fresh mount of the same chat restores both. This only works if
  the partial state is held outside the LiveView process (ActiveTasks), so the
  remount is the real test — not the original view.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "a mid-stream reload restores the partial reply" do
    scenario "reply streams a chunk, then the founder reloads" do
      given_ "a signed-in founder whose reply has streamed a partial chunk", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          chunks: ["Draft so far: the granite shop is open"],
          hang: true
        })

        {:ok, view, _html} = live(conn, "/chat")

        view
        |> form("[data-test='chat-form']", message: %{content: "draft the post"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn})}
      end

      when_ "the founder reloads the page mid-stream", context do
        {:ok, reloaded_view, _html} = live(context.conn, "/chat")
        {:ok, Map.put(context, :reloaded_view, reloaded_view)}
      end

      then_ "the partial assistant text is restored on the fresh mount", context do
        assert has_element?(
                 context.reloaded_view,
                 "[data-test='assistant-message']",
                 "Draft so far: the granite shop is open"
               )

        :ok
      end

      then_ "the in-progress indicator is restored too", context do
        assert has_element?(context.reloaded_view, "[data-test='streaming-indicator']")
        :ok
      end
    end
  end
end
