defmodule MarketMySpecSpex.Story744.Criterion6590Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6590 — Model switch applies only to the next message and is recorded

  Rule R5: provider and model are selectable per conversation; a change applies
  to the next message only, and each assistant message records the provider and
  model that produced it. The founder sends one message on the default
  Anthropic model, switches the selector to an OpenAI model, then sends another
  — the first assistant message still shows Anthropic, the second shows OpenAI.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/chat").
  Each assistant bubble exposes its origin via data-provider / data-model.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "switching the model only affects messages sent afterward" do
    scenario "first message on Anthropic, switch, second message on OpenAI" do
      given_ "a signed-in founder on a chat defaulting to Anthropic", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _html} = live(conn, "/chat")
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends one message, switches to OpenAI, and sends another", context do
        Application.put_env(:market_my_spec, :chat_llm, %{
          chunks: ["Anthropic reply"],
          finish_reason: "stop",
          provider: "anthropic",
          model: "claude-sonnet-4-6"
        })

        context.view
        |> form("[data-test='chat-form']", message: %{content: "first on anthropic"})
        |> render_submit()

        context.view
        |> form("[data-test='model-form']", conversation: %{provider: "openai", model: "gpt-5-mini"})
        |> render_change()

        Application.put_env(:market_my_spec, :chat_llm, %{
          chunks: ["OpenAI reply"],
          finish_reason: "stop",
          provider: "openai",
          model: "gpt-5-mini"
        })

        context.view
        |> form("[data-test='chat-form']", message: %{content: "second on openai"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the first assistant message records the Anthropic model", context do
        assert has_element?(
                 context.view,
                 "[data-test='assistant-message'][data-provider='anthropic'][data-model='claude-sonnet-4-6']"
               )

        {:ok, context}
      end

      then_ "the second assistant message records the OpenAI model", context do
        assert has_element?(
                 context.view,
                 "[data-test='assistant-message'][data-provider='openai'][data-model='gpt-5-mini']"
               )

        {:ok, context}
      end
    end
  end
end
