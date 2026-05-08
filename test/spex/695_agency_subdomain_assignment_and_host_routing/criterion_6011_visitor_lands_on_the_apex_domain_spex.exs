defmodule MarketMySpecSpex.Story695.Criterion6011Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6011 — Visitor lands on the apex domain

  Story rule: the apex domain serves the default platform surface with
  no agency scope, regardless of any agency's configuration.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Agencies.HostResolver
  alias MarketMySpecSpex.Fixtures

  spex "visitor lands on the apex domain" do
    scenario "visitor on marketmyspec.com sees the default platform surface" do
      given_ "an agency 'Acme Marketing' with subdomain 'acme' configured", context do
        owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(owner)
        {:ok, _} = HostResolver.claim_subdomain(agency, "acme")

        {:ok, Map.put(context, :agency, agency)}
      end

      when_ "a visitor navigates to marketmyspec.com/", context do
        visitor_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "marketmyspec.com")

        {:ok, view, html} = live(visitor_conn, "/")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the page renders the default platform surface (not agency-scoped)", context do
        # Acme's name should NOT appear on the apex landing page even
        # though Acme has a configured subdomain — apex is platform-only.
        refute context.html =~ context.agency.name,
               "expected the agency name to NOT appear on the apex landing page"

        {:ok, context}
      end
    end
  end
end
