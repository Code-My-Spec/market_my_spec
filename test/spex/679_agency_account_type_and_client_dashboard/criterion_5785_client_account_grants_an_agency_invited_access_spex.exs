defmodule MarketMySpecSpex.Story679.Criterion5785Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5785 — Client account grants an agency invited access

  Story rule: an existing client account can grant an agency access
  by invitation. The grant has origination_status="invited" and the
  client appears on the agency dashboard.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "client account grants an agency invited access" do
    scenario "client owner grants an agency access at level account_manager and the client surfaces on the agency dashboard", context do
      given_ "a client-account owner", context do
        client_owner = Fixtures.user_fixture()
        {client_token, _raw} = Fixtures.generate_user_magic_link_token(client_owner)
        {:ok, Map.merge(context, %{client_owner: client_owner, client_token: client_token})}
      end

      given_ "an agency-account owner with an admin-provisioned agency", context do
        agency_owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(agency_owner)
        {agency_token, _raw} = Fixtures.generate_user_magic_link_token(agency_owner)

        {:ok,
         Map.merge(context, %{
           agency_owner: agency_owner,
           agency_token: agency_token,
           agency: agency
         })}
      end

      when_ "the client owner signs in and creates a client account 'Inviting Client Co'", context do
        client_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.client_token}})

        {:ok, view, _html} = live(client_conn, "/accounts/new")

        view
        |> form("[data-test='account-form']", account: %{name: "Inviting Client Co"})
        |> render_submit()

        {:ok, Map.put(context, :client_conn, client_conn)}
      end

      when_ "the client owner grants the agency access at level 'account_manager'", context do
        {:ok, view, _html} = live(context.client_conn, ~p"/accounts")

        view
        |> form("[data-test='grant-agency-access-form']",
          grant: %{
            agency_slug: context.agency.slug,
            access_level: "account_manager"
          }
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the agency dashboard lists 'Inviting Client Co' as an invited grant at account_manager", context do
        agency_conn =
          Phoenix.ConnTest.build_conn()
          |> post("/users/log-in", %{"user" => %{"token" => context.agency_token}})

        {:ok, view, dashboard_html} = live(agency_conn, "/agency")

        assert dashboard_html =~ ~r/Inviting Client Co/,
               "expected the new client to appear on the agency dashboard"

        assert has_element?(view, "[data-test='client-row-invited'][data-access-level='account_manager']"),
               "expected an invited row at access_level=account_manager"

        :ok
      end
    end
  end
end
