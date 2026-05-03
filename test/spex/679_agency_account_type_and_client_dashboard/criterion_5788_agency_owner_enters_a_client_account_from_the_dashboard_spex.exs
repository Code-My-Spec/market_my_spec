defmodule MarketMySpecSpex.Story679.Criterion5788Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5788 — Agency owner enters a client account from the dashboard

  Story rule: clicking a client row in the dashboard sets that account
  as the user's current context and routes to the dashboard scoped to
  that client. A visual indicator confirms the user is operating
  inside the client account.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "agency owner enters a client account from the dashboard" do
    scenario "clicking a client row switches context and renders the inside-client indicator" do
      given_ "an agency with a client 'Click Through Client'", context do
        agency_owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(agency_owner)
        {token, _raw} = Fixtures.generate_user_magic_link_token(agency_owner)

        {:ok,
         Map.merge(context, %{
           agency_owner: agency_owner,
           token: token,
           agency: agency
         })}
      end

      when_ "the agency owner signs in and creates 'Click Through Client'", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, view, _html} = live(authed_conn, "/agency/clients/new")

        view
        |> form("[data-test='client-form']", client: %{name: "Click Through Client"})
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the agency owner clicks the client row to switch context", context do
        {:ok, view, _html} = live(context.conn, "/agency")

        view
        |> element("[data-test='client-row'][data-client-name='Click Through Client'] [data-test='enter-client']")
        |> render_click()

        {:ok, context}
      end

      then_ "the inside-client indicator is present on the dashboard", context do
        {:ok, view, html} = live(context.conn, "/accounts")

        assert has_element?(view, "[data-test='inside-client-indicator']"),
               "expected an inside-client visual indicator after switching context"

        assert html =~ ~r/Click Through Client/,
               "expected the current client name to be visible in the indicator"

        {:ok, context}
      end
    end
  end
end
