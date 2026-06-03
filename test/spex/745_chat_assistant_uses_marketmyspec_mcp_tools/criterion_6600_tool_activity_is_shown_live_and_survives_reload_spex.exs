defmodule MarketMySpecSpex.Story745.Criterion6600Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6600 — Tool activity is shown live and survives reload

  Rule: tool activity is visible to the user while it runs and persists with the
  conversation across reload. The `:chat_llm` fixture scripts a tool call + a
  continuation; the tool step shows in the thread, and after a reload the tool
  step and the final answer are still there (loaded from persisted :tool /
  assistant messages).

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "tool activity is shown and survives a reload" do
    scenario "a tool-using exchange is reloaded" do
      given_ "a signed-in founder in a Problem Discovery chat whose reply uses a tool", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          tool_calls: [%{name: "list_candidates", arguments: %{}}],
          chunks_after_tool: ["Your board has open candidates to review."],
          finish_reason: "stop"
        })

        {:ok, view, _html} = live(conn, "/app/chat")

        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "problem_discovery"})
        |> render_submit()

        view
        |> form("[data-test='chat-form']", message: %{content: "review my board"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      then_ "the tool step is shown live", context do
        assert has_element?(context.view, "[data-test='tool-call']", "list_candidates")
        {:ok, context}
      end

      when_ "the founder reloads the chat", context do
        {:ok, reloaded_view, html} = live(context.conn, "/app/chat")
        {:ok, Map.merge(context, %{reloaded_view: reloaded_view, html: html})}
      end

      then_ "the tool step and the final answer are still shown after reload", context do
        assert has_element?(context.reloaded_view, "[data-test='tool-call']", "list_candidates")
        assert context.html =~ "Your board has open candidates to review."
        refute has_element?(context.reloaded_view, "[data-test='streaming-indicator']")
        {:ok, context}
      end
    end
  end
end
