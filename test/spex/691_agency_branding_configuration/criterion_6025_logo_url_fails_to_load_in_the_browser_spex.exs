defmodule MarketMySpecSpex.Story691.Criterion6025Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6025 — Logo URL fails to load in the browser

  Story rule: the agency logo renders in a fixed top-left navbar slot.
  If the logo URL fails to load in the browser, the agency's name
  renders as a text fallback in the same slot.

  Server-side specs cannot trigger an actual image-load failure (that
  happens client-side). The contract we can assert from a rendered
  page: the navbar logo slot contains BOTH the logo image (with the
  configured URL) AND the agency's name as accessible fallback text
  (via `alt` attribute or sibling text), so the browser's image-load
  failure surfaces the name automatically.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "logo URL fails to load in the browser" do
    scenario "the navbar slot pairs the logo image with the agency name as fallback text" do
      given_ "an agency 'Acme Marketing' with subdomain 'acme' and a logo URL configured", context do
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
          branding: %{logo_url: "https://acme.example/missing.png"}
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

      then_ "the navbar logo slot contains both the logo URL and the agency name as fallback text", context do
        assert has_element?(context.view, "[data-test='agency-navbar-logo']"),
               "expected the agency-navbar-logo slot in the navbar"

        assert context.html =~ "https://acme.example/missing.png",
               "expected the configured logo URL to appear in the rendered page"

        # The agency name must be present in the navbar slot as
        # accessible fallback text — either the img's `alt` attribute or
        # a sibling text node — so a browser image-load failure surfaces
        # the name. The agency_account_fixture generates a unique
        # auto-named account; assert against that name.
        assert context.html =~ context.agency.name,
               "expected the agency name #{inspect(context.agency.name)} as fallback text in the navbar slot"

        {:ok, context}
      end
    end
  end
end
