defmodule MarketMySpecSpex.Story691.Criterion6022Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6022 — Visitor on an unconfigured agency subdomain sees default theme

  Story rule: when an agency has not configured branding, requests on
  that agency's subdomain render with the Market My Spec default
  theme (the canonical `marketmyspec-dark` data-theme).

  Depends on story 695 for host-based agency resolution.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "visitor on an unconfigured agency subdomain sees default theme" do
    scenario "agency 'Acme Marketing' has subdomain 'acme' but no branding; visitor sees the platform default theme" do
      given_ "an agency 'Acme Marketing' with subdomain 'acme' and NO branding configured", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

        # Set ONLY the subdomain — no logo, no colors.
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, settings_view, _html} = live(authed_conn, "/agency/settings")

        settings_view
        |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "acme"})
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

      then_ "the page renders with the Market My Spec default theme tokens", context do
        # The default theme is keyed on `marketmyspec-dark` (or
        # `marketmyspec-light`) via `data-theme`. An unbranded agency
        # subdomain must render one of these defaults rather than an
        # agency-specific theme.
        assert context.html =~ ~r/data-theme=['"]marketmyspec-(dark|light)['"]/,
               "expected the default Market My Spec theme tokens in the rendered page"

        {:ok, context}
      end
    end
  end
end
