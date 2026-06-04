defmodule MarketMySpecSpex.Story745.Criterion6597Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6597 — The tool runs for real against my account

  Rule: a tool call executes the real MarketMySpec tool, scoped to the
  conversation's account. The real registry is configured and the `:chat_llm`
  fixture scripts the model to call list_candidates; the real tool executes with
  the account's scope and the account's own data shows in the tool step.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat"), real
  registry (`:chat_tool_registry_module`).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn ->
      Application.delete_env(:market_my_spec, :chat_llm)
      Application.delete_env(:market_my_spec, :chat_tool_registry_module)
    end)

    :ok
  end

  spex "the real tool executes against my account's data" do
    scenario "list_candidates returns my account's candidates" do
      given_ "a signed-in founder whose account has a candidate, in a Problem Discovery chat", context do
        user = Fixtures.user_fixture()
        scope = Fixtures.user_scope_fixture(user)
        Fixtures.frame_fixture(scope, %{title: "alpha-frame"})
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_tool_registry_module, MarketMySpec.Chat.McpToolRegistry)

        Application.put_env(:market_my_spec, :chat_llm, %{
          tool_calls: [%{name: "list_frames", arguments: %{}}],
          chunks_after_tool: ["Here is what is on your board."],
          finish_reason: "stop"
        })

        {:ok, view, _html} = live(conn, "/app/chat")

        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "problem_discovery"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder asks about the board", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "what's on my board?"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the tool step reflects my account's real frame", context do
        assert has_element?(context.view, "[data-test='tool-call']", "alpha-frame")
        {:ok, context}
      end
    end
  end
end
