defmodule MarketMySpecSpex.Story695.Criterion6008Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6008 — Visitor hits an active agency subdomain

  Story rule: requests to a known agency subdomain
  (`<subdomain>.marketmyspec.com`) resolve into that agency's scoped
  LiveView context. Until the host plug ships, this spec asserts at
  the request layer that the apex domain renders the LV — once the
  plug lands, this scenario should additionally assert the agency
  context is set.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Agencies.HostResolver
  alias MarketMySpecSpex.Fixtures

  spex "visitor hits an active agency subdomain" do
    scenario "visitor on acme.marketmyspec.com gets a 200 LiveView response" do
      given_ "Acme Marketing has subdomain 'acme'", context do
        owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(owner)
        {:ok, _} = HostResolver.claim_subdomain(agency, "acme")

        {:ok, Map.put(context, :agency, agency)}
      end

      when_ "an unauthenticated visitor navigates to acme.marketmyspec.com/", context do
        visitor_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "acme.marketmyspec.com")

        {:ok, view, html} = live(visitor_conn, "/")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the LiveView mounts and the page references the agency", context do
        assert is_binary(context.html), "expected an HTML body"

        assert context.html =~ context.agency.name,
               "expected the agency name #{inspect(context.agency.name)} to appear on its own subdomain"

        {:ok, context}
      end
    end
  end
end
