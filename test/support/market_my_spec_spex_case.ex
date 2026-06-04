defmodule MarketMySpecSpex.Case do
  @moduledoc """
  Base case for spex (BDD spec) tests.

  Wires up Phoenix.ConnTest for HTTP assertions, Phoenix.LiveViewTest
  for driving LiveViews, the SexySpex DSL (spex/scenario/given_/when_/then_),
  and the DB sandbox.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint MarketMySpecWeb.Endpoint
      @moduletag timeout: 300_000

      use MarketMySpecWeb, :verified_routes
      use SexySpex

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import MarketMySpecSpex.Case

      @doc """
      Drives the chats index→show flow: opens `/app/chats`, clicks the "New
      chat" button for `type` (`:problem_discovery` | `:marketing_strategy`),
      follows the navigation, and returns the mounted `ChatLive.Show` view.
      """
      def start_chat(conn, type) do
        {:ok, index, _html} = live(conn, "/app/chats")

        {:error, {:live_redirect, %{to: path}}} =
          index
          |> element("[data-test='new-chat-#{type}']")
          |> render_click()

        {:ok, show, _html} = live(conn, path)
        show
      end

      @doc "Extracts the conversation id from a mounted `ChatLive.Show` view."
      def chat_id(view) do
        [id] =
          Regex.run(~r/data-chat-id="([^"]+)"/, render(view), capture: :all_but_first)

        id
      end
    end
  end

  setup tags do
    MarketMySpecSpex.Fixtures.setup_sandbox(tags)
    purge_files_memory()
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  defp purge_files_memory do
    if :ets.whereis(:market_my_spec_files_memory) != :undefined do
      :ets.delete_all_objects(:market_my_spec_files_memory)
    end
  end
end
