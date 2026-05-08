defmodule MarketMySpecSpex.Story691.Criterion6024Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6024 — Visitor on a different agency's subdomain sees that agency's branding only

  Story rule: agency branding is scoped to the agency's own subdomain.
  Acme's primary color must NOT appear on Beta's subdomain, and vice
  versa.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "visitor on a different agency's subdomain sees that agency's branding only" do
    scenario "two agencies with distinct branding render in isolation; Beta's subdomain shows Beta's primary, not Acme's" do
      given_ "two agencies with distinct subdomains and primary colors", context do
        alice = Fixtures.user_fixture()
        bob = Fixtures.user_fixture()
        acme = Fixtures.agency_account_fixture(alice)
        beta = Fixtures.agency_account_fixture(bob)

        {alice_token, _} = Fixtures.generate_user_magic_link_token(alice)
        {bob_token, _} = Fixtures.generate_user_magic_link_token(bob)

        # Configure Acme: subdomain "acme", primary "#22c55e".
        alice_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => alice_token}})
        {:ok, acme_view, _} = live(alice_conn, "/agency/settings")

        acme_view
        |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "acme"})
        |> render_submit()

        acme_view
        |> form("[data-test='branding-form']", branding: %{primary_color: "#22c55e"})
        |> render_submit()

        # Configure Beta: subdomain "beta", primary "#dc2626".
        bob_conn =
          Phoenix.ConnTest.build_conn()
          |> post("/users/log-in", %{"user" => %{"token" => bob_token}})

        {:ok, beta_view, _} = live(bob_conn, "/agency/settings")

        beta_view
        |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "beta"})
        |> render_submit()

        beta_view
        |> form("[data-test='branding-form']", branding: %{primary_color: "#dc2626"})
        |> render_submit()

        {:ok, Map.merge(context, %{acme: acme, beta: beta})}
      end

      when_ "an unauthenticated visitor navigates to beta.marketmyspec.com", context do
        visitor_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "beta.marketmyspec.com")

        {:ok, view, html} = live(visitor_conn, "/")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the page renders with Beta's primary color and does NOT apply Acme's branding", context do
        assert context.html =~ "#dc2626",
               "expected Beta's primary color (#dc2626) in the rendered page"

        refute context.html =~ "#22c55e",
               "expected Acme's primary color (#22c55e) to NOT appear on Beta's subdomain"

        {:ok, context}
      end
    end
  end
end
