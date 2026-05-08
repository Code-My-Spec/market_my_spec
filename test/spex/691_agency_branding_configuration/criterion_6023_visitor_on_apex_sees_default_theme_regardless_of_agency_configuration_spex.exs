defmodule MarketMySpecSpex.Story691.Criterion6023Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6023 — Visitor on apex sees default theme regardless of agency configuration

  Story rule: agency branding never bleeds onto the apex domain. Even
  if an agency has fully configured branding, a visitor hitting
  `marketmyspec.com` (apex, no agency scope) sees the platform's
  default theme and the platform's default logo.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "visitor on apex sees default theme regardless of agency configuration" do
    scenario "Acme Marketing has fully configured branding, but apex still renders the platform default" do
      given_ "an agency 'Acme Marketing' with subdomain 'acme' and fully configured branding", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

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

      when_ "an unauthenticated visitor navigates to the apex marketmyspec.com", context do
        visitor_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "marketmyspec.com")

        {:ok, view, html} = live(visitor_conn, "/")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the apex renders with the default theme and does NOT apply the agency's branding", context do
        assert context.html =~ ~r/data-theme=['"]marketmyspec-(dark|light)['"]/,
               "expected the default Market My Spec theme on apex"

        refute context.html =~ "#22c55e",
               "expected the agency's primary color to NOT appear on apex"

        refute context.html =~ "#1d4ed8",
               "expected the agency's secondary color to NOT appear on apex"

        refute context.html =~ "https://acme.example/logo.svg",
               "expected the agency's logo URL to NOT appear on apex"

        {:ok, context}
      end
    end
  end
end
