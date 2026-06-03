defmodule MarketMySpecSpex.Story744.Criterion6582Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6582 — Empty or whitespace-only message is rejected

  Rule R1 (failure path): an empty or whitespace-only message is rejected and
  nothing is persisted. The thread gains no user bubble and a fresh mount of
  the chat is still empty.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "a whitespace-only message never enters the thread" do
    scenario "submit '   ' → no user bubble, nothing persisted" do
      given_ "a signed-in founder on an empty active chat", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: [], hang: true})

        {:ok, view, _html} = live(conn, "/chat")
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder submits a whitespace-only message", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "   "})
        |> render_submit()

        {:ok, context}
      end

      then_ "no user message is added to the thread", context do
        # Anchor: the chat surface is genuinely rendered (the form is present)…
        assert has_element?(context.view, "[data-test='chat-form']")
        # …yet no user bubble was created.
        refute has_element?(context.view, "[data-test='user-message']")
        {:ok, context}
      end

      then_ "nothing was persisted — a fresh mount is still empty", context do
        {:ok, fresh_view, _html} = live(context.conn, "/chat")

        assert has_element?(fresh_view, "[data-test='chat-form']")
        refute has_element?(fresh_view, "[data-test='user-message']")
        {:ok, context}
      end
    end
  end
end
