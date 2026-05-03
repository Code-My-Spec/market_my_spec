defmodule MarketMySpecSpex.Story679.Criterion5789Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5789 — Read-only agency user cannot modify client account settings

  Story rule: an agency with read_only access to a client can view
  artifacts and settings but cannot create, edit, or delete data
  inside that client.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "read-only agency user cannot modify client account settings" do
    scenario "operating inside a read_only client context, edit/delete controls are absent and the manage form is disabled" do
      given_ "an agency with read_only access to a client account", context do
        agency_owner = Fixtures.user_fixture()
        client_owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(agency_owner)
        client_account = Fixtures.account_fixture(client_owner, %{name: "Read Only Client"})
        Fixtures.invited_grant_fixture(agency, client_account, access_level: "read_only")
        {token, _raw} = Fixtures.generate_user_magic_link_token(agency_owner)

        {:ok,
         Map.merge(context, %{
           agency_owner: agency_owner,
           token: token,
           agency: agency,
           client_account: client_account
         })}
      end

      when_ "the agency owner signs in and switches into the read-only client", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency")

        view
        |> element(
          "[data-test='client-row'][data-client-id='#{context.client_account.id}'] [data-test='enter-client']"
        )
        |> render_click()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the client manage page exposes no edit or delete affordances", context do
        {:ok, view, _html} = live(context.conn, ~p"/accounts/#{context.client_account.id}/manage")

        refute has_element?(view, "[data-test='account-form'] button[type='submit']"),
               "expected no submit button on the manage form for a read_only agency user"

        refute has_element?(view, "[data-test='delete-account']"),
               "expected no delete-account control under read_only access"

        {:ok, context}
      end
    end
  end
end
