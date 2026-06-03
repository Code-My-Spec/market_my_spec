defmodule MarketMySpecSpex.Story745.Criterion6602Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6602 — Tools cannot reach another account's data

  Rule: a conversation's tools only ever touch that conversation's own account.
  Account A and account B each have a candidate; chatting in account A, the
  real list_candidates tool returns only A's candidate — B's is never reachable.

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

  spex "a chat's tools never reach another account's data" do
    scenario "account A's chat lists only account A's candidates" do
      given_ "two accounts each with their own candidate, signed in as account A", context do
        user_a = Fixtures.user_fixture()
        Fixtures.candidate_fixture(Fixtures.user_scope_fixture(user_a), %{title: "alpha-candidate"})

        user_b = Fixtures.user_fixture()
        Fixtures.candidate_fixture(Fixtures.user_scope_fixture(user_b), %{title: "beta-candidate"})

        {token, _} = Fixtures.generate_user_magic_link_token(user_a)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_tool_registry_module, MarketMySpec.Chat.McpToolRegistry)

        Application.put_env(:market_my_spec, :chat_llm, %{
          tool_calls: [%{name: "list_candidates", arguments: %{}}],
          chunks_after_tool: ["Here is your board."],
          finish_reason: "stop"
        })

        {:ok, view, _html} = live(conn, "/app/chat")

        view
        |> form("[data-test='new-chat-form']", conversation: %{type: "problem_discovery"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder asks the assistant to list candidates", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "list my candidates"})
        |> render_submit()

        {:ok, context}
      end

      then_ "only account A's candidate is shown", context do
        assert has_element?(context.view, "[data-test='tool-call']", "alpha-candidate")
        {:ok, context}
      end

      then_ "account B's candidate is never reachable", context do
        refute render(context.view) =~ "beta-candidate"
        {:ok, context}
      end
    end
  end
end
