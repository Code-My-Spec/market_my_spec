defmodule MarketMySpecSpex.Story745.Criterion6603Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6603 — A plain message still streams as before

  Rule: filling the tool seam does not change the existing chat streaming
  contract — a message that needs no tool streams a plain text reply with no
  tool call, exactly as in story 744.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive.Show at "/app/chats/:id").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "a no-tool message streams plain text" do
    scenario "send a message that needs no tool" do
      given_ "a signed-in founder in a Problem Discovery chat", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        Application.put_env(:market_my_spec, :chat_llm, %{
          chunks: ["A plain text answer, no tools needed."],
          finish_reason: "stop"
        })

        view = start_chat(conn, :problem_discovery)

        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder sends a message that needs no tool", context do
        context.view
        |> form("[data-test='chat-form']", message: %{content: "hello, just say hi"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the reply is plain text", context do
        assert has_element?(context.view, "[data-test='assistant-message']", "A plain text answer, no tools needed.")
        {:ok, context}
      end

      then_ "no tool call appears", context do
        refute has_element?(context.view, "[data-test='tool-call']")
        {:ok, context}
      end
    end
  end
end
