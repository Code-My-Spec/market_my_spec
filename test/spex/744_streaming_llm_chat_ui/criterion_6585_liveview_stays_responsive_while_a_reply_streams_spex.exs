defmodule MarketMySpecSpex.Story744.Criterion6585Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6585 — LiveView stays responsive while a reply streams

  Rule R3: LLM calls run in a supervised background task, so the LiveView never
  blocks. With a reply still streaming (the `:chat_llm` fixture hangs), the
  founder can still send another message and the UI keeps responding. The
  LiveView process issues no synchronous provider call of its own — if it did,
  this interaction would block behind the in-flight stream.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the founder can interact with the page mid-stream" do
    scenario "send another message while a reply streams" do
      given_ "a signed-in founder with a reply streaming indefinitely", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["streaming"], hang: true})

        {:ok, view, _html} = live(conn, "/app/chat")

        view
        |> form("[data-test='chat-form']", message: %{content: "first prompt"})
        |> render_submit()

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends another message mid-stream", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "second prompt while streaming"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the second message is accepted while the reply is still streaming", context do
        html = render(context.view)

        assert html =~ "second prompt while streaming"
        # The in-progress reply is still shown — the page did not hang or reset.
        assert has_element?(context.view, "[data-test='streaming-indicator']")
        {:ok, context}
      end

      then_ "the input stays usable", context do
        assert has_element?(context.view, "[data-test='chat-form']")
        refute has_element?(context.view, "[data-test='chat-form'] [disabled]")
        {:ok, context}
      end
    end
  end
end
