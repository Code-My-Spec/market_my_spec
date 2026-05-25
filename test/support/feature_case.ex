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
      import MarketMySpecWeb.FeatureCase, only: [log_in_via_magic_link: 2]

      alias MarketMySpec.Repo
      alias MarketMySpecWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  Signs a Wallaby session in via a magic-link token, returning the session.

  Visits `/users/log-in/<token>`, clicks the primary confirm/login button
  (`data-test='confirm-login'` — present in both the unconfirmed and
  confirmed branches of UserLive.Confirmation), then blocks until the
  `phx-trigger-action` form POST to UserSessionController has set the
  session and the browser has navigated off the login page. Without that
  wait, a subsequent `visit/2` races ahead of the async login POST and
  lands on the "You must log in" redirect.
  """
  def log_in_via_magic_link(session, token) do
    session
    |> Wallaby.Browser.visit("/users/log-in/#{token}")
    |> Wallaby.Browser.click(Wallaby.Query.css("[data-test='confirm-login']"))

    wait_until_authenticated(session, 10_000)
    session
  end

  defp wait_until_authenticated(session, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_authenticated(session, deadline)
  end

  defp do_wait_authenticated(session, deadline) do
    url = Wallaby.Browser.current_url(session)

    cond do
      # Navigated off the magic-link confirmation page → login POST landed.
      not String.contains?(url, "/users/log-in") -> :ok
      System.monotonic_time(:millisecond) >= deadline -> :ok
      true ->
        Process.sleep(300)
        do_wait_authenticated(session, deadline)
    end
  end

  setup do
    # Wallaby needs base_url set to drive relative visit/2 paths. Point it
    # at the local test endpoint. (JourneyCase overrides this per-test for
    # deployed-env runs; FeatureCase tests are always local.)
    Application.put_env(:wallaby, :base_url, MarketMySpecWeb.Endpoint.url())

    # NOTE: sandbox checkout + session metadata wiring is handled by
    # `use Wallaby.Feature`'s own setup. Do NOT also start_owner! here —
    # a second checkout puts the test process on a different connection
    # than the browser, so data the test inserts is invisible to the
    # browser (manifested as "Magic link is invalid" — the live mount
    # couldn't see the just-inserted token).
    :ok
  end
end
