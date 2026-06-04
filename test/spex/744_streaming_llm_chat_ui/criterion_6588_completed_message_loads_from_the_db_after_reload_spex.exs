defmodule MarketMySpecSpex.Story744.Criterion6588Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6588 — Completed message loads from the DB after reload

  Rule R4: once a reply has finished streaming, a reload loads the finalized
  assistant message from the database with no loading state. The `:chat_llm`
  fixture completes normally; after the stream is done the founder reloads and
  sees the persisted reply and no in-progress indicator.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive.Show at "/app/chats/:id").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "a completed reply reloads from the database, not as a loading state" do
    scenario "reply completes, then the founder reloads" do
      given_ "a signed-in founder whose reply completes", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          chunks: ["The granite shop is now open for business."],
          finish_reason: "stop",
          usage: %{input_tokens: 12, output_tokens: 9, cost: 0.0003},
          response_id: "resp_done_1",
          provider: "anthropic",
          model: "claude-sonnet-4-6"
        })

        view = start_chat(conn, :problem_discovery)

        view
        |> form("[data-test='chat-form']", message: %{content: "is the shop open?"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, chat_id: chat_id(view)})}
      end

      when_ "the founder reloads the page after the reply finished", context do
        {:ok, reloaded_view, html} = live(context.conn, "/app/chats/#{context.chat_id}")
        {:ok, Map.merge(context, %{reloaded_view: reloaded_view, html: html})}
      end

      then_ "the completed assistant message is loaded from the database", context do
        assert context.html =~ "The granite shop is now open for business."
        {:ok, context}
      end

      then_ "no loading or in-progress indicator is shown", context do
        refute has_element?(context.reloaded_view, "[data-test='streaming-indicator']")
        {:ok, context}
      end
    end
  end
end
