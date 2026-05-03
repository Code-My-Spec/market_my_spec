defmodule MarketMySpecSpex.Story679.Criterion5786Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5786 — Either party can revoke an invited access grant

  Story rule: an invited access grant can be revoked by either the
  agency or the client owner. After revocation the client no longer
  appears on the agency dashboard.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "either party can revoke an invited access grant" do
    scenario "agency owner clicks 'Revoke' on the invited row and the client disappears from the dashboard" do
      given_ "an invited access grant between an agency and a client account", context do
        client_owner = Fixtures.user_fixture()
        agency_owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(agency_owner)
        client_account = Fixtures.account_fixture(client_owner, %{name: "Revoke Test Client"})
        Fixtures.invited_grant_fixture(agency, client_account, access_level: "account_manager")
        {agency_token, _raw} = Fixtures.generate_user_magic_link_token(agency_owner)

        {:ok,
         Map.merge(context, %{
           agency_owner: agency_owner,
           agency_token: agency_token,
           agency: agency,
           client_account: client_account
         })}
      end

      when_ "the agency owner signs in and clicks Revoke on the invited row", context do
        agency_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.agency_token}})

        {:ok, view, _html} = live(agency_conn, "/agency")

        view
        |> element(
          "[data-test='client-row-invited'][data-client-id='#{context.client_account.id}'] [data-test='revoke-grant']"
        )
        |> render_click()

        {:ok, Map.put(context, :conn, agency_conn)}
      end

      then_ "the client no longer appears on the agency dashboard", context do
        {:ok, _view, dashboard_html} = live(context.conn, "/agency")

        refute dashboard_html =~ ~r/Revoke Test Client/,
               "expected the revoked client to be absent from the agency dashboard"

        {:ok, context}
      end
    end
  end
end
