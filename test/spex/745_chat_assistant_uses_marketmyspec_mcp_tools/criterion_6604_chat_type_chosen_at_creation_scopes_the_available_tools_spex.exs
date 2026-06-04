defmodule MarketMySpecSpex.Story745.Criterion6604Spex do
  @moduledoc """
  Story 745 — Chat Assistant Uses MarketMySpec MCP Tools
  Criterion 6604 — Chat type chosen at creation scopes the available tools

  Rule: a chat is created with a type (Problem Discovery or Marketing Strategy);
  its type determines which tools the assistant can use. Choosing a type at
  creation is reflected on the chat, and choosing the other type yields the
  other type's chat.

  Interaction surface: LiveView (chats index `MarketMySpecWeb.ChatLive.Index` at
  "/app/chats" → `MarketMySpecWeb.ChatLive.Show` at "/app/chats/:id").
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup do
    # A marketing-strategy chat kicks off a reply on creation (type property),
    # so script the model deterministically rather than hitting the real API.
    Application.put_env(:market_my_spec, :chat_llm, %{chunks: ["ready"], finish_reason: "stop"})
    on_exit(fn -> Application.delete_env(:market_my_spec, :chat_llm) end)
    :ok
  end

  spex "the chat type chosen at creation is applied to the chat" do
    scenario "start a Problem Discovery chat" do
      given_ "a signed-in founder on the chats index", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, Map.merge(context, %{conn: conn})}
      end

      when_ "the founder starts a Problem Discovery chat", context do
        view = start_chat(context.conn, :problem_discovery)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chat is a Problem Discovery chat", context do
        assert has_element?(context.view, "[data-test='chat'][data-chat-type='problem_discovery']")
        {:ok, context}
      end
    end

    scenario "start a Marketing Strategy chat" do
      given_ "a signed-in founder on the chats index", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, Map.merge(context, %{conn: conn})}
      end

      when_ "the founder starts a Marketing Strategy chat", context do
        view = start_chat(context.conn, :marketing_strategy)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the chat is a Marketing Strategy chat", context do
        assert has_element?(context.view, "[data-test='chat'][data-chat-type='marketing_strategy']")
        {:ok, context}
      end
    end
  end
end
