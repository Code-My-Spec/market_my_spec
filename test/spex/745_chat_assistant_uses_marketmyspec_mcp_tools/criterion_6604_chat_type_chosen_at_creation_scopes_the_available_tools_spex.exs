defmodule MarketMySpecSpex.Story745.Criterion6604Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6604 — Chat type chosen at creation scopes the available tools

  Rule: a chat is created with a type (Problem Discovery or Marketing Strategy);
  its type determines which tools the assistant can use. Choosing a type at
  creation is reflected on the chat, and choosing the other type yields the
  other type's chat.

  Interaction surface: LiveView (MarketMySpecWeb.ChatLive at "/app/chat").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the chat type chosen at creation is applied to the chat" do
    scenario "start a Problem Discovery chat" do
      given_ "a signed-in founder starting a new chat", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _html} = live(conn, "/app/chat")
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder chooses the Problem Discovery chat type", context do
        context.view
        |> form("[data-test='new-chat-form']", conversation: %{type: "problem_discovery"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the chat is a Problem Discovery chat", context do
        assert has_element?(context.view, "[data-test='chat'][data-chat-type='problem_discovery']")
        {:ok, context}
      end
    end

    scenario "start a Marketing Strategy chat" do
      given_ "a signed-in founder starting a new chat", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _html} = live(conn, "/app/chat")
        {:ok, Map.merge(context, %{conn: conn, view: view})}
      end

      when_ "the founder chooses the Marketing Strategy chat type", context do
        context.view
        |> form("[data-test='new-chat-form']", conversation: %{type: "marketing_strategy"})
        |> render_submit()

        {:ok, context}
      end

      then_ "the chat is a Marketing Strategy chat", context do
        assert has_element?(context.view, "[data-test='chat'][data-chat-type='marketing_strategy']")
        {:ok, context}
      end
    end
  end
end
