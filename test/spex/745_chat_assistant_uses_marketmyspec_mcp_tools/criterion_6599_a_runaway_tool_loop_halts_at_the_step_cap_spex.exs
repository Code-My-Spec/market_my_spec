defmodule MarketMySpecSpex.Story745.Criterion6599Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6599 — A runaway tool loop halts at the step cap

  Rule: the tool-call loop is bounded by a maximum number of steps to control
  cost. The `:chat_llm` fixture scripts a model that requests a tool on every
  turn forever; the runner stops calling tools at the configured cap and returns
  a final message instead of looping indefinitely.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "a runaway tool loop stops at the step cap" do
    scenario "the model keeps requesting tools every turn" do
      given_ "a signed-in founder in a Problem Discovery chat whose model never stops calling tools", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        # tool_calls_every_turn: the scripted model emits this tool call on every
        # turn and never finishes on its own — only the step cap stops it.
        Application.put_env(:market_my_spec, :chat_llm, %{
          tool_calls_every_turn: %{name: "list_candidates", arguments: %{}}
        })

        {:ok, view, _html} = live(conn, "/app/chat")

        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "problem_discovery"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a message that triggers the runaway loop", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "go"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the loop stops and the reply finalizes instead of hanging", context do
        # The loop halted: no perpetual in-progress indicator, and a final
        # assistant message exists.
        refute has_element?(context.view, "[data-test='streaming-indicator']")
        assert has_element?(context.view, "[data-test='assistant-message']")
        {:ok, context}
      end

      then_ "the step cap is reported to the user", context do
        assert has_element?(context.view, "[data-test='step-limit-notice']")
        {:ok, context}
      end
    end
  end
end
