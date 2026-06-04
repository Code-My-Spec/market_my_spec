defmodule MarketMySpecSpex.Story744.Criterion6584Spex do
  @moduledoc """
  Story 744 — Streaming LLM Chat UI
  Criterion 6584 — Long reply renders progressively with an in-progress affordance

  Rule R2: the assistant response streams into the UI incrementally. With the
  `:chat_llm` fixture emitting an early chunk and then hanging (not finalising),
  the partial text is visible in the thread AND an in-progress indicator is
  shown — proving the reply renders progressively rather than all-at-once at the
  end.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive.Show at "/app/chats/:id").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "partial assistant text appears with an in-progress indicator" do
    scenario "a reply emits an early chunk and is still streaming" do
      given_ "a signed-in founder whose reply streams an early chunk then keeps going", context do
        user = Fixtures.user_fixture()
        _account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          chunks: ["Here is the first part of the launch post"],
          hang: true
        })

        view = start_chat(conn, :problem_discovery)
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a prompt that yields a long reply", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "write me a long launch post"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the partial assistant text is already visible before completion", context do
        assert has_element?(
                 context.view,
                 "[data-test='assistant-message']",
                 "Here is the first part of the launch post"
               )

        {:ok, context}
      end

      then_ "an in-progress indicator is shown while the reply is unfinished", context do
        assert has_element?(context.view, "[data-test='streaming-indicator']")
        {:ok, context}
      end
    end
  end
end
