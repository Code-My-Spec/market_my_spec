defmodule MarketMySpecSpex.Story745.Criterion6601Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6601 — A failing tool does not crash the chat

  Rule: a tool failure surfaces as a recoverable state, not a crash, and the
  assistant can still respond. The `:chat_llm` fixture scripts a tool call whose
  tool errors; the error is fed back to the model as a tool result (not a
  runner crash), the assistant continues, and the LiveView stays usable.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "a failing tool is recoverable, not a crash" do
    scenario "the tool errors and the assistant recovers" do
      given_ "a signed-in founder in a Problem Discovery chat whose tool will error", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          tool_calls: [%{name: "list_candidates", arguments: %{}, error: "the board is unavailable"}],
          chunks_after_tool: ["I couldn't reach your board just now, but I can still help."],
          finish_reason: "stop"
        })

        {:ok, view, _html} = live(conn, "/app/chat")

        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "problem_discovery"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a message and the tool errors", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "what's on my board?"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the tool step shows the failure rather than crashing", context do
        assert has_element?(context.view, "[data-test='tool-call']")
        assert render(context.view) =~ "the board is unavailable"
        {:ok, context}
      end

      then_ "the assistant still responds and the chat stays usable", context do
        assert has_element?(
                 context.view,
                 "[data-test='assistant-message']",
                 "I couldn't reach your board just now, but I can still help."
               )

        assert has_element?(context.view, "[data-test='chat-form']")
        {:ok, context}
      end
    end
  end
end
