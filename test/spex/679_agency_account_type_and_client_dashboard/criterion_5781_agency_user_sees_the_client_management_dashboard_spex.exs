defmodule MarketMySpecSpex.Story679.Criterion5781Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5781 — Agency user sees the client management dashboard

  Story rule: only agency-type accounts have access to the client
  management dashboard. A user operating in an agency context can
  reach /agency and see their portfolio.

  Note: depends on `agency_account_fixture/1` (admin-provisioned agency).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "agency user sees the client management dashboard" do
    scenario "user operating in an agency-typed account context renders the agency dashboard" do
      given_ "a user with an admin-provisioned agency account", context do
        user = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(user)
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token, agency: agency})}
      end

      when_ "the user signs in", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the agency dashboard renders with the client portfolio container", context do
        {:ok, view, _html} = live(context.conn, "/agency")
        assert has_element?(view, "[data-test='agency-client-dashboard']"),
               "expected the agency client dashboard container at /agency"

        {:ok, context}
      end
    end
  end
end
