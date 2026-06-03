defmodule MarketMySpecSpex.Story744.Criterion6583Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6583 — A second message sent mid-stream is persisted in order

  Rule R1: while the first assistant reply is still streaming, the founder can
  send a second message; both user messages are persisted in send order. The
  `:chat_llm` fixture hangs (streams indefinitely) so the first reply is still
  in flight when the second message is sent.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "two messages sent during an in-flight reply keep their order" do
    scenario "send 'first', then 'second' while the reply streams" do
      given_ "a signed-in founder whose first reply will stream indefinitely", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["thinking"], hang: true})

        {:ok, view, _html} = live(conn, "/chat")
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends 'first' and then 'second' before the reply finishes", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "first question"})
        |> render_submit()

        context.view
        |> form("[data-test='chat-form']", message: %{content: "second question"})
        |> render_submit()

        {:ok, context}
      end

      then_ "both user messages are present in send order", context do
        html = render(context.view)

        assert html =~ "first question"
        assert html =~ "second question"

        first_at = :binary.match(html, "first question") |> elem(0)
        second_at = :binary.match(html, "second question") |> elem(0)
        assert first_at < second_at, "expected 'first question' to render before 'second question'"

        :ok
      end

      then_ "both survive a reload in the same order", context do
        {:ok, _fresh, fresh_html} = live(context.conn, "/chat")

        first_at = :binary.match(fresh_html, "first question") |> elem(0)
        second_at = :binary.match(fresh_html, "second question") |> elem(0)
        assert first_at < second_at
        :ok
      end
    end
  end
end
