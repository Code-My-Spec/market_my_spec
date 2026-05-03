defmodule MarketMySpecSpex.Story679.Criterion5796Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5796 — Dashboard variant with a status column is rejected

  Story rule: rows expose name + access level only. A 'Status' column
  header or status cell is a violation.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "dashboard variant with a status column is rejected by the column audit" do
    scenario "the rendered agency dashboard contains no Status header and no client-status cell" do
      given_ "an agency with at least one client", context do
        agency_owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(agency_owner)
        Fixtures.originated_client_fixture(agency, %{name: "Status Audit Client"})
        {token, _raw} = Fixtures.generate_user_magic_link_token(agency_owner)
        {:ok, Map.merge(context, %{token: token})}
      end

      when_ "the agency owner signs in and visits the dashboard", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, view, html} = live(authed_conn, "/agency")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the dashboard renders the client row, but no status header or status cell exists", context do
        assert context.html =~ ~r/Status Audit Client/,
               "anchor: expected the test client row to render"

        refute context.html =~ ~r/<th[^>]*>\s*status\s*<\/th>/i,
               "expected no 'Status' table header on the agency dashboard"

        refute has_element?(context.view, "[data-test='client-row'] [data-test='client-status']"),
               "expected no client-status cell on dashboard rows"

        refute has_element?(context.view, "[data-test='status-column']"),
               "expected no status column container on the dashboard"

        {:ok, context}
      end
    end
  end
end
