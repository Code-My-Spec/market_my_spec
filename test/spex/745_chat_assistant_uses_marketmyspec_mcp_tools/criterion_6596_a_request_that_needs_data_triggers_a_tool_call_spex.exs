defmodule MarketMySpecSpex.Story745.Criterion6596Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6596 — A request that needs data triggers a tool call

  Rule: when a user's request needs one, the assistant calls a tool available
  for the chat's type. In a Problem Discovery chat, a request about the board's
  data drives a Problem Discovery tool call (e.g. list_candidates), and only a
  tool belonging to this chat's type.

  The `:chat_llm` fixture scripts the model to emit the tool call; the tool step
  is observable in the thread.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "a data request triggers a Problem Discovery tool call" do
    scenario "ask about unlabeled candidates" do
      given_ "a signed-in founder in a Problem Discovery chat", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          tool_calls: [%{name: "list_candidates", arguments: %{}}],
          chunks_after_tool: ["You have unlabeled candidates remaining."],
          finish_reason: "stop"
        })

        {:ok, view, _html} = live(conn, "/chat")

        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "problem_discovery"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder asks which candidates are still unlabeled", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "which candidates are still unlabeled?"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the assistant called a Problem Discovery tool", context do
        assert has_element?(context.view, "[data-test='tool-call']", "list_candidates")
        {:ok, context}
      end
    end
  end
end
