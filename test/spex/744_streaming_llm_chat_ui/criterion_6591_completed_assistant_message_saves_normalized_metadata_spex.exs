defmodule MarketMySpecSpex.Story744.Criterion6591Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6591 — Completed assistant message saves normalized metadata

  Rule R6: on completion the assistant message persists normalized metadata —
  provider, model, input/output tokens, cost, finish reason, and response id —
  and the header token/cost badges reflect it after a reload. The `:chat_llm`
  fixture completes with a full usage payload; the badges are asserted on a
  fresh mount so the metadata is proven persisted, not just held in memory.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "completed reply persists usage metadata shown after reload" do
    scenario "reply completes with full usage, then the founder reloads" do
      given_ "a signed-in founder whose reply completes with usage metadata", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          chunks: ["A complete, costed reply."],
          finish_reason: "stop",
          usage: %{input_tokens: 40, output_tokens: 8, cost: 0.000470},
          response_id: "resp_meta_1",
          provider: "anthropic",
          model: "claude-sonnet-4-6"
        })

        {:ok, view, _html} = live(conn, "/app/chat")

        view
        |> form("[data-test='chat-form']", message: %{content: "give me a costed reply"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn})}
      end

      when_ "the founder reloads after the reply completes", context do
        {:ok, reloaded_view, html} = live(context.conn, "/app/chat")
        {:ok, Map.merge(context, %{reloaded_view: reloaded_view, html: html})}
      end

      then_ "the token badge reflects the persisted token counts", context do
        # 40 input + 8 output = 48 total tokens.
        assert render(element(context.reloaded_view, "[data-test='token-badge']")) =~ "48"
        {:ok, context}
      end

      then_ "the cost badge reflects the persisted cost", context do
        assert render(element(context.reloaded_view, "[data-test='cost-badge']")) =~ "0.000470"
        {:ok, context}
      end

      then_ "the assistant message records provider, model, and finish reason", context do
        assert has_element?(
                 context.reloaded_view,
                 "[data-test='assistant-message'][data-provider='anthropic'][data-model='claude-sonnet-4-6'][data-finish-reason='stop']"
               )

        {:ok, context}
      end
    end
  end
end
