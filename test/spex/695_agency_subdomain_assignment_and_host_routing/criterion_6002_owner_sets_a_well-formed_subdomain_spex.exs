defmodule MarketMySpecSpex.Story695.Criterion6002Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6002 — Owner sets a well-formed subdomain

  Story rule: subdomain format = lowercase alphanumeric + hyphens,
  3-50 chars, must start with a letter, must not be reserved.
  A well-formed value ('acme-marketing') is accepted.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner sets a well-formed subdomain" do
    scenario "owner submits 'acme-marketing' and the value is accepted" do
      given_ "an agency 'Acme Marketing' with no subdomain set", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits subdomain 'acme-marketing'", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        view
        |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "acme-marketing"})
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the value is accepted and prefilled on reload", context do
        {:ok, view, html} = live(context.conn, "/agency/settings")
        assert html =~ ~r/value=['"]acme-marketing['"]/,
               "expected the saved subdomain to be prefilled"

        # No error span on the subdomain field after a successful save.
        refute has_element?(view, "[data-test='subdomain-form'] [phx-feedback-for]"),
               "expected no per-field error feedback on the subdomain form"

        {:ok, context}
      end
    end
  end
end
