defmodule MarketMySpecWeb.FeatureCase do
  @moduledoc """
  Test case for browser-driven journey tests using Wallaby.

  Each test gets a Wallaby session pinned to the same DB connection as the
  test process via `Phoenix.Ecto.SQL.Sandbox`, so writes done in seeds /
  fixtures are visible to the browser without manual sync.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      import MarketMySpec.UsersFixtures

      alias MarketMySpec.Repo
      alias MarketMySpecWeb.Router.Helpers, as: Routes
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MarketMySpec.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, metadata: Phoenix.Ecto.SQL.Sandbox.metadata_for(MarketMySpec.Repo, pid)}
  end
end
