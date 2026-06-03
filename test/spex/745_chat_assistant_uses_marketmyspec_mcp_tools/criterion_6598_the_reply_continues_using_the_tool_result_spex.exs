defmodule MarketMySpecSpex.Story745.Criterion6598Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6598 — The reply continues using the tool result

  Rule: after a tool returns, the assistant feeds the result back and continues
  its reply. The `:chat_llm` fixture scripts a tool call followed by a
  continuation; the continuation — only reachable after the tool result is fed
  back into the model — appears in the final assistant message.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the streamed reply continues after the tool runs" do
    scenario "tool call then continuation" do
      given_ "a signed-in founder in a Problem Discovery chat whose reply uses a tool", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          tool_calls: [%{name: "list_candidates", arguments: %{}}],
          chunks_after_tool: ["Based on the board, your top unlabeled candidate is the granite shop lead."],
          finish_reason: "stop"
        })

        {:ok, view, _html} = live(conn, "/app/chat")

        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "problem_discovery"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a message that uses the tool", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "summarize my board"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the assistant's reply continues after the tool result", context do
        assert has_element?(
                 context.view,
                 "[data-test='assistant-message']",
                 "Based on the board, your top unlabeled candidate is the granite shop lead."
               )

        {:ok, context}
      end

      then_ "the reply finalized normally", context do
        refute has_element?(context.view, "[data-test='streaming-indicator']")
        refute has_element?(context.view, "[data-test='message-error']")
        {:ok, context}
      end
    end
  end
end
