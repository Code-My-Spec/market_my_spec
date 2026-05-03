defmodule MarketMySpecSpex.Story679.Criterion5784Spex do
  @moduledoc """
  Story 679 — Agency Account Type And Client Dashboard
  Criterion 5784 — Originator access grant cannot be revoked

  Story rule: when an agency creates a client account, the resulting
  originator grant is permanent. The dashboard does not expose a
  revoke control on originator-marked rows; an attempt to revoke is
  rejected.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "originator access grant cannot be revoked" do
    scenario "the agency dashboard exposes no revoke control on originator rows", context do
      given_ "an agency that has originated a client account", context do
        user = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(user)
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token, agency: agency})}
      end

      when_ "the user signs in and creates a client 'Originator Client'", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, view, _html} = live(authed_conn, "/agency/clients/new")

        view
        |> form("[data-test='client-form']", client: %{name: "Originator Client"})
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the originator row exposes no revoke control", context do
        {:ok, view, _html} = live(context.conn, "/agency")

        assert has_element?(view, "[data-test='client-row-originator']"),
               "anchor: expected an originator-marked client row"

        refute has_element?(
                 view,
                 "[data-test='client-row-originator'] [data-test='revoke-grant']"
               ),
               "expected no revoke control on an originator-marked row"

        :ok
      end
    end
  end
end
