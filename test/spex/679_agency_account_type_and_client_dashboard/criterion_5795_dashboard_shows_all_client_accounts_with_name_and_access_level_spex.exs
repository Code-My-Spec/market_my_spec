defmodule MarketMySpecSpex.Story679.Criterion5795Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5795 — Dashboard shows all client accounts with name and access level

  Story rule: the agency dashboard lists every managed client account
  with the agency's access level. Originated and invited grants both
  appear; the visual difference is access-level labeling, not a
  separate column.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "dashboard shows all client accounts with name and access level" do
    scenario "an agency with two originated and one invited client sees all three rows with access-level cells", context do
      given_ "an agency with two originated clients and one invited client", context do
        agency_owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(agency_owner)
        Fixtures.originated_client_fixture(agency, %{name: "Originated One"})
        Fixtures.originated_client_fixture(agency, %{name: "Originated Two"})

        invited_owner = Fixtures.user_fixture()
        invited_client = Fixtures.account_fixture(invited_owner, %{name: "Invited Client"})
        Fixtures.invited_grant_fixture(agency, invited_client, access_level: "account_manager")

        {token, _raw} = Fixtures.generate_user_magic_link_token(agency_owner)
        {:ok, Map.merge(context, %{token: token})}
      end

      when_ "the agency owner signs in and visits the dashboard", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, view, html} = live(authed_conn, "/agency")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "all three clients are listed with name and access-level cells", context do
        assert context.html =~ ~r/Originated One/, "expected Originated One on the dashboard"
        assert context.html =~ ~r/Originated Two/, "expected Originated Two on the dashboard"
        assert context.html =~ ~r/Invited Client/, "expected Invited Client on the dashboard"

        rows = Floki.parse_document!(context.html) |> Floki.find("[data-test='client-row']")
        assert length(rows) == 3, "expected 3 client rows, got #{length(rows)}"

        Enum.each(rows, fn row ->
          assert Floki.find(row, "[data-test='client-name']") != [],
                 "expected each row to expose client-name"

          assert Floki.find(row, "[data-test='access-level']") != [],
                 "expected each row to expose access-level"
        end)

        :ok
      end
    end
  end
end
