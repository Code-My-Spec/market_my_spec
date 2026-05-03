defmodule MarketMySpecSpex.Story679.Criterion5792Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5792 — Agency team member navigates into a client account

  Story rule: any agency team member (not just the owner) can switch
  into a client account through the agency-client grant. The current
  context becomes the client account.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "agency team member navigates into a client account" do
    scenario "a non-owner agency member clicks a client row and the context switches" do
      given_ "an agency, a non-owner team member, and a client", context do
        agency_owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(agency_owner)
        team_member = Fixtures.user_fixture()
        Fixtures.account_member_fixture(agency, team_member, role: "member")
        client_owner = Fixtures.user_fixture()
        client_account = Fixtures.account_fixture(client_owner, %{name: "Team Nav Client"})
        Fixtures.invited_grant_fixture(agency, client_account, access_level: "account_manager")
        {token, _raw} = Fixtures.generate_user_magic_link_token(team_member)

        {:ok,
         Map.merge(context, %{
           team_member: team_member,
           token: token,
           client_account: client_account
         })}
      end

      when_ "the team member signs in and clicks the client row from /agency", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, view, _html} = live(authed_conn, "/agency")

        view
        |> element(
          "[data-test='client-row'][data-client-id='#{context.client_account.id}'] [data-test='enter-client']"
        )
        |> render_click()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the inside-client indicator is present and names the target client", context do
        {:ok, view, html} = live(context.conn, "/accounts")

        assert has_element?(view, "[data-test='inside-client-indicator']"),
               "expected the inside-client indicator after a non-owner navigates into a client"

        assert html =~ ~r/Team Nav Client/,
               "expected the inside-client indicator to name the client account"

        {:ok, context}
      end
    end
  end
end
