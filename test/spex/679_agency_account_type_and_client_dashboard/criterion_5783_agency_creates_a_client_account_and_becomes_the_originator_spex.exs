defmodule MarketMySpecSpex.Story679.Criterion5783Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5783 — Agency creates a client account and becomes the originator

  Story rule: when an agency creates a client account, an
  agency_client_access_grant with origination_status="originator" is
  recorded; the new client appears on the agency dashboard.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "agency creates a client account and becomes the originator" do
    scenario "agency owner creates 'Bright Ideas Co' through the dashboard and the client appears with originator marker" do
      given_ "a user with an admin-provisioned agency account", context do
        user = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(user)
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token, agency: agency})}
      end

      when_ "the user signs in and creates a client 'Bright Ideas Co' from /agency", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/clients/new")

        view
        |> form("[data-test='client-form']", client: %{name: "Bright Ideas Co"})
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the agency dashboard lists 'Bright Ideas Co' marked as originator", context do
        {:ok, view, dashboard_html} = live(context.conn, "/agency")

        assert dashboard_html =~ ~r/Bright Ideas Co/,
               "expected the new client to appear in the dashboard"

        assert has_element?(view, "[data-test='client-row-originator']"),
               "expected an originator-marked row in the agency dashboard"

        {:ok, context}
      end
    end
  end
end
