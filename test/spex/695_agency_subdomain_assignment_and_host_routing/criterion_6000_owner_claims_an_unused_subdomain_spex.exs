defmodule MarketMySpecSpex.Story695.Criterion6000Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6000 — Owner claims an unused subdomain

  Story rule: an agency owner can claim a globally-unique subdomain on
  marketmyspec.com. The subdomain is recorded on the agency and future
  requests to `<subdomain>.marketmyspec.com` resolve into the agency
  context.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner claims an unused subdomain" do
    scenario "agency owner submits 'acme' as the agency's subdomain on the settings form" do
      given_ "an agency 'Acme Marketing' with no subdomain set and Alice as owner", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits subdomain 'acme' on the settings form", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        view
        |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "acme"})
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the subdomain is saved on the agency and prefilled on reload", context do
        {:ok, _view, html} = live(context.conn, "/agency/settings")
        assert html =~ ~r/value=['"]acme['"]/,
               "expected the saved subdomain to be prefilled in the settings form"

        {:ok, context}
      end
    end
  end
end
