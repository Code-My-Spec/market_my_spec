defmodule MarketMySpecSpex.Story744.Criterion6585Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6585 — LiveView stays responsive while a reply streams

  Rule R3: LLM calls run in a supervised background task, so the LiveView never
  blocks. With a reply still streaming (the `:chat_llm` fixture hangs), the
  founder can still change the model selector and send another message, and the
  UI keeps responding. The synchronous LiveView process issues no provider call
  of its own — if it did, these interactions would block behind the stream.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the founder can interact with the page mid-stream" do
    scenario "change the model and send another message while a reply streams" do
      given_ "a signed-in founder with a reply streaming indefinitely", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["streaming"], hang: true})

        {:ok, view, _html} = live(conn, "/chat")

        view
        |> form("[data-test='chat-form']", message: %{content: "first prompt"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder changes the model and sends another message mid-stream", context do
        context.view
        |> form("[data-test='model-form']", conversation: %{provider: "openai", model: "gpt-5-mini"})
        |> render_change()

        context.view
        |> form("[data-test='chat-form']", message: %{content: "second prompt while streaming"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the second message is accepted and the page is still streaming", context do
        html = render(context.view)

        assert html =~ "second prompt while streaming"
        # The in-progress reply is still shown — the page did not hang or reset.
        assert has_element?(context.view, "[data-test='streaming-indicator']")
        :ok
      end

      then_ "the model selector reflects the founder's mid-stream change", context do
        assert has_element?(context.view, "[data-test='model-form'] [value='gpt-5-mini']")
        :ok
      end
    end
  end
end
