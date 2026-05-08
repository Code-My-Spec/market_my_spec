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

      use MarketMySpecWeb, :verified_routes
      use SexySpex

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import MarketMySpecSpex.Case
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
