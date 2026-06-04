defmodule MarketMySpecSpex.Story744.Criterion6592Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6592 — Empty tool registry yields a pure text stream

  Rule R7: the runner consults a tool registry around each LLM call; in v0 it
  returns no tools, so the model is called with no tools, emits no tool call,
  and the reply is a plain text stream. With the default (empty) registry, a
  sent message yields a text-only assistant reply and no tool-call affordance
  ever appears in the thread.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive.Show at "/app/chats/:id"). The
  "called with no tools" half of the rule is exercised at the runner unit
  level; the surface-observable half is "a pure text reply, no tool-call UI",
  asserted here.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the default empty registry produces a text-only reply" do
    scenario "send a message with no tools registered" do
      given_ "a signed-in founder on a chat with the default empty tool registry", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          chunks: ["A plain text answer with no tools involved."],
          finish_reason: "stop"
        })

        view = start_chat(conn, :problem_discovery)
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a message", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "what should I post today?"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the reply renders as plain text", context do
        assert has_element?(
                 context.view,
                 "[data-test='assistant-message']",
                 "A plain text answer with no tools involved."
               )

        {:ok, context}
      end

      then_ "no tool-call affordance appears in the thread", context do
        refute has_element?(context.view, "[data-test='tool-call']")
        {:ok, context}
      end
    end
  end
end
