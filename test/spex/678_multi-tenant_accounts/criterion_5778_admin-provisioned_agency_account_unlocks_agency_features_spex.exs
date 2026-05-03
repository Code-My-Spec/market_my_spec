defmodule MarketMySpecSpex.Story678.Criterion5778Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5778 — Admin-provisioned agency account unlocks agency features

  Story rule: when an admin has provisioned an agency account for a
  user, that user — operating in the agency account context — sees the
  agency management dashboard in navigation and white label settings in
  account settings.

  Note: this scenario depends on an `agency_account_fixture/1` that
  creates an admin-provisioned agency account. Until that fixture
  ships, the spec will fail.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "admin-provisioned agency account unlocks agency features" do
    scenario "operating in an admin-provisioned agency account exposes the agency dashboard nav link and white label settings", context do
      given_ "a user with an admin-provisioned agency account", context do
        user = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(user)
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token, agency: agency})}
      end

      when_ "the user signs in and switches into the agency account context", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the agency management dashboard nav link is visible", context do
        {:ok, view, _html} = live(context.conn, "/accounts")

        assert has_element?(view, "[data-test='nav-agency-dashboard']"),
               "expected agency dashboard nav link in admin-provisioned agency account"

        :ok
      end

      then_ "white label settings are accessible in account settings", context do
        {:ok, view, _html} = live(context.conn, ~p"/accounts/#{context.agency.id}/manage")

        assert has_element?(view, "[data-test='white-label-settings']"),
               "expected white-label settings to be accessible in agency account settings"

        :ok
      end
    end
  end
end
