defmodule MarketMySpecSpex.Story691.Criterion6021Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6021 — Visitor on a configured agency subdomain sees branding

  Story rule: when a request resolves into an agency context (i.e., on
  the agency's subdomain), the agency's configured logo and colors are
  applied via daisyUI's `--color-primary` and `--color-secondary`
  tokens. Branding includes the navbar logo slot.

  Depends on story 695 (subdomain assignment + host routing). Until
  the host plug ships, the test conn won't resolve a subdomain into an
  agency scope and this spec will fail.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "visitor on a configured agency subdomain sees branding" do
    scenario "agency 'Acme Marketing' with subdomain 'acme' and configured branding renders the agency's colors and logo" do
      given_ "an agency 'Acme Marketing' with subdomain 'acme' and configured branding", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

        # Set the subdomain and branding via the form to drive the real
        # surface (this is the canonical setup once the implementation
        # lands; until then this scenario will fail at this step).
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, settings_view, _html} = live(authed_conn, "/agency/settings")

        settings_view
        |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "acme"})
        |> render_submit()

        settings_view
        |> form("[data-test='branding-form']",
          branding: %{
            logo_url: "https://acme.example/logo.svg",
            primary_color: "#22c55e",
            secondary_color: "#1d4ed8"
          }
        )
        |> render_submit()

        {:ok, Map.merge(context, %{alice: alice, agency: agency})}
      end

      when_ "an unauthenticated visitor navigates to acme.marketmyspec.com", context do
        visitor_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "acme.marketmyspec.com")

        {:ok, view, html} = live(visitor_conn, "/")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the rendered page applies the agency's primary and secondary colors and shows the logo in the navbar slot", context do
        assert context.html =~ "#22c55e",
               "expected the agency's primary color (#22c55e) in the rendered page"

        assert context.html =~ "#1d4ed8",
               "expected the agency's secondary color (#1d4ed8) in the rendered page"

        assert has_element?(context.view, "[data-test='agency-navbar-logo']"),
               "expected the agency-navbar-logo slot to be present"

        assert context.html =~ "https://acme.example/logo.svg",
               "expected the agency's logo URL to appear in the rendered page"

        {:ok, context}
      end
    end
  end
end
