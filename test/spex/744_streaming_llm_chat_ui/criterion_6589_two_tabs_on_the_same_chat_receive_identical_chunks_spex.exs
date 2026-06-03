defmodule MarketMySpecSpex.Story744.Criterion6589Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6589 — Two tabs on the same chat receive identical chunks

  Rule R4: multiple subscribers on the same chat topic all receive identical
  stream chunks. Two LiveView mounts on the same active chat both render the
  same streamed assistant text — the reply fans out over PubSub on
  "chat:<chat_id>", it is not local to the tab that sent the message.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/chat"), two
  concurrent mounts sharing one authenticated session.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "both open tabs see the same streamed reply" do
    scenario "send from tab one, observe in tab two" do
      given_ "a signed-in founder with two tabs open on the same chat", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          chunks: ["Shared reply across both tabs"],
          finish_reason: "stop"
        })

        {:ok, tab_one, _} = live(conn, "/chat")
        {:ok, tab_two, _} = live(conn, "/chat")

        {:ok, Map.merge(context, %{conn: conn, tab_one: tab_one, tab_two: tab_two})}
      end

      when_ "the founder sends a message from the first tab", context do
        context.tab_one
        |> form("[data-test='chat-form']", message: %{content: "hello from tab one"})
        |> render_submit()

        # Let the second tab's process drain the broadcast chunks.
        _ = :sys.get_state(context.tab_two.pid)
        {:ok, context}
      end

      then_ "the first tab shows the streamed reply", context do
        assert has_element?(context.tab_one, "[data-test='assistant-message']", "Shared reply across both tabs")
        {:ok, context}
      end

      then_ "the second tab shows the identical streamed reply", context do
        assert has_element?(context.tab_two, "[data-test='assistant-message']", "Shared reply across both tabs")
        {:ok, context}
      end
    end
  end
end
