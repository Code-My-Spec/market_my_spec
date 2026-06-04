defmodule MarketMySpecSpex.Story744.Criterion6581Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6581 — User message is persisted and echoed immediately

  Rule R1: the user message is persisted and shown immediately, before any
  assistant response. The founder sends a message and it appears in the thread
  at once, with the input still free to accept another — no assistant content
  has to exist yet. Persistence is proven by a fresh mount of the same chat.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive.Show at "/app/chats/:id").
  The external LLM is held off via the `:chat_llm` fixture so the assertion
  is purely about the user echo, independent of any reply.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the founder's message is echoed and persisted before any reply" do
    scenario "send a message → it appears at once and survives a reload" do
      given_ "a signed-in founder on an active chat with no reply pending", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        # The provider never completes here — this criterion is about the user
        # echo, not the assistant reply.
        Application.put_env(:market_my_spec, :chat_llm, %{chunks: [], hang: true})

        view = start_chat(conn, :problem_discovery)
        {:ok, Map.merge(context, %{conn: conn, view: view, chat_id: chat_id(view)})}
      end

      when_ "the founder sends 'draft a launch post for the granite shop'", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "draft a launch post for the granite shop"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the message shows in the thread immediately as a user message", context do
        assert has_element?(
                 context.view,
                 "[data-test='user-message']",
                 "draft a launch post for the granite shop"
               )

        {:ok, context}
      end

      then_ "the input is still free to accept another message", context do
        assert has_element?(context.view, "[data-test='chat-form']")
        refute has_element?(context.view, "[data-test='chat-form'] [disabled]")
        {:ok, context}
      end

      then_ "the message is persisted — a fresh mount still shows it", context do
        {:ok, _fresh_view, fresh_html} = live(context.conn, "/app/chats/#{context.chat_id}")

        assert fresh_html =~ "draft a launch post for the granite shop"
        {:ok, context}
      end
    end
  end
end
