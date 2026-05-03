defmodule MarketMySpecSpex.Story679.Criterion5791Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5791 — Dashboard rows show name and access level only

  Story rule: agency dashboard rows display the client account name
  and the agency's access level only. No status, billing, MRR, or
  last-activity columns are present.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "dashboard rows show only name and access level" do
    scenario "the rendered dashboard row exposes name + access-level cells but no extra columns", context do
      given_ "an agency with at least one client", context do
        agency_owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(agency_owner)
        client_owner = Fixtures.user_fixture()
        client_account = Fixtures.account_fixture(client_owner, %{name: "Columns Audit Client"})
        Fixtures.invited_grant_fixture(agency, client_account, access_level: "account_manager")
        {token, _raw} = Fixtures.generate_user_magic_link_token(agency_owner)
        {:ok, Map.merge(context, %{token: token})}
      end

      when_ "the agency owner signs in and visits the dashboard", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, view, html} = live(authed_conn, "/agency")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "each row renders only data-test='client-name' and data-test='access-level' cells", context do
        assert has_element?(context.view, "[data-test='client-row'] [data-test='client-name']"),
               "expected client-name cell"

        assert has_element?(context.view, "[data-test='client-row'] [data-test='access-level']"),
               "expected access-level cell"

        refute has_element?(context.view, "[data-test='client-row'] [data-test='client-status']"),
               "expected no status cell"

        refute has_element?(context.view, "[data-test='client-row'] [data-test='client-mrr']"),
               "expected no MRR cell"

        refute has_element?(context.view, "[data-test='client-row'] [data-test='client-last-activity']"),
               "expected no last-activity cell"

        :ok
      end
    end
  end
end
