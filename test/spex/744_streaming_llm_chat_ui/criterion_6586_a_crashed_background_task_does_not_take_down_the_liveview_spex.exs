defmodule MarketMySpecSpex.Story744.Criterion6586Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6586 — A crashed background task does not take down the LiveView

  Rule R3 (failure path): when the supervised streaming task crashes, the
  supervisor restarts cleanly and the LiveView shows an error state rather than
  hanging or dying. The `:chat_llm` fixture is set to crash the streaming task.
  The founder still has a live, usable chat afterward.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "a crashing stream task surfaces an error, not a dead page" do
    scenario "the background task crashes mid-reply" do
      given_ "a signed-in founder whose streaming task will crash", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{crash: true})

        {:ok, view, _html} = live(conn, "/app/chat")
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a message and the task crashes", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "trigger a crash"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the message enters an error state instead of hanging forever", context do
        assert has_element?(context.view, "[data-test='message-error']")
        # No perpetual in-progress spinner left behind by the dead task.
        refute has_element?(context.view, "[data-test='streaming-indicator']")
        {:ok, context}
      end

      then_ "the LiveView is still alive and usable", context do
        assert has_element?(context.view, "[data-test='chat-form']")
        # The founder's own message is still in the thread — the page did not reset.
        assert has_element?(context.view, "[data-test='user-message']", "trigger a crash")
        {:ok, context}
      end
    end
  end
end
