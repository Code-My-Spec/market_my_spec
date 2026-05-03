defmodule MarketMySpecSpex.Story678.Criterion5776Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5776 — Agency account unlocks agency features

  Story rule: agency accounts are admin-provisioned only — self-service
  always produces individual accounts. Once a user is in an agency
  account context, the agency management dashboard is accessible in
  navigation and white label settings are accessible in account
  settings.

  Note: this scenario depends on an admin-provisioning fixture
  (`agency_account_fixture/1` or similar) that does not exist yet. The
  spec will fail until that fixture ships and self-service ignores any
  user-supplied `type` field.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "agency account unlocks agency features" do
    scenario "operating inside an admin-provisioned agency account exposes the agency dashboard nav link", context do
      given_ "a user who has been admin-provisioned an agency account", context do
        user = Fixtures.user_fixture()
        # Future fixture: agency_account_fixture(user) creates an
        # agency-typed account with `user` as owner.
        agency_account = Fixtures.agency_account_fixture(user)
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token, agency: agency_account})}
      end

      when_ "the user signs in and lands in the agency account context", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the agency dashboard nav link is present", context do
        {:ok, view, _html} = live(context.conn, "/accounts")
        assert has_element?(view, "[data-test='nav-agency-dashboard']"),
               "expected agency dashboard nav link in agency account context"

        refute has_element?(view, "[data-test='nav-agency-dashboard'][hidden]"),
               "expected agency dashboard nav link to be visible, not hidden"

        :ok
      end
    end
  end
end
