defmodule MarketMySpecSpex.Story695.Criterion6006Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6006 — Admin changes the subdomain

  Story rule: an agency member with `:manage_account` rights (owner OR
  admin) can change the agency's subdomain. An admin who is not the
  owner is allowed.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Agencies.HostResolver
  alias MarketMySpecSpex.Fixtures

  spex "admin changes the subdomain" do
    scenario "agency admin Alice updates 'acme' to 'acme-co' through the settings form" do
      given_ "an agency 'Acme Marketing' with subdomain 'acme' and Alice as admin", context do
        owner = Fixtures.user_fixture()
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(owner)
        {:ok, _} = HostResolver.claim_subdomain(agency, "acme")
        Fixtures.account_member_fixture(agency, alice, role: "admin")
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits subdomain 'acme-co'", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        view
        |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "acme-co"})
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the new subdomain is saved and prefilled on reload", context do
        {:ok, _view, html} = live(context.conn, "/agency/settings")

        assert html =~ ~r/value=['"]acme-co['"]/,
               "expected the new subdomain 'acme-co' to be prefilled after admin update"

        {:ok, context}
      end
    end
  end
end
