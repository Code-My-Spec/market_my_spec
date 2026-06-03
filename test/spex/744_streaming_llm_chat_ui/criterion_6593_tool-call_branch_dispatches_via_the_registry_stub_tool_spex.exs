defmodule MarketMySpecSpex.Story744.Criterion6593Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6593 — Tool-call branch dispatches via the registry (stub tool)

  Rule R7: the runner's tool-call branch — though unreachable with the empty v0
  registry — is present and exercised with a stub registry returning one fake
  tool. When the model's response requests that tool, the runner dispatches it
  through the registry, feeds the result back, and continues streaming, with no
  change to the LiveView / PubSub contract.

  Driven end-to-end through the real surface: a stub registry (one fake tool
  plus its canned result) is configured via `:chat_tool_registry`, and the
  `:chat_llm` fixture scripts a response that requests the tool and then
  continues with text once the tool result is fed back. The observable proof is
  that the assistant message ends with the continuation text — which can only
  appear if the tool was dispatched, returned, and the stream resumed.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn ->
      Application.delete_env(:market_my_spec, :chat_llm)
      Application.delete_env(:market_my_spec, :chat_tool_registry)
    end)

    :ok
  end

  spex "a requested tool is dispatched and the stream continues" do
    scenario "stub registry returns one tool; the model asks for it" do
      given_ "a signed-in founder on a chat backed by a one-tool stub registry", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        # The stub registry returns exactly one fake tool and a canned result for it.
        Application.put_env(:market_my_spec, :chat_tool_registry, %{
          tools: [%{name: "lookup_fact", result: "GRANITE_FACT"}]
        })

        # The scripted response: request the tool, then — after the tool result
        # is fed back — continue with text that embeds the result.
        Application.put_env(:market_my_spec, :chat_llm, %{
          tool_calls: [%{name: "lookup_fact", arguments: %{}}],
          chunks_after_tool: ["Using the fact: GRANITE_FACT, here is the answer."],
          finish_reason: "stop"
        })

        {:ok, view, _html} = live(conn, "/chat")
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a message that triggers the tool", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "look up a granite fact"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the continuation text — only reachable after dispatch — is shown", context do
        assert has_element?(
                 context.view,
                 "[data-test='assistant-message']",
                 "Using the fact: GRANITE_FACT, here is the answer."
               )

        :ok
      end

      then_ "the reply finalizes normally — the contract is unchanged", context do
        refute has_element?(context.view, "[data-test='streaming-indicator']")
        refute has_element?(context.view, "[data-test='message-error']")
        :ok
      end
    end
  end
end
