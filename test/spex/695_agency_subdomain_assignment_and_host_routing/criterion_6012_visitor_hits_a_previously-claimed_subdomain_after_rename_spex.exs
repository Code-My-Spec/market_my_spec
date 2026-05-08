defmodule MarketMySpecSpex.Story695.Criterion6012Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6012 — Visitor hits a previously-claimed subdomain after rename

  This criterion was authored under an earlier rule that distinguished
  stale-subdomain (404) from never-claimed (302 redirect). The current
  rule treats both identically — any unrecognized subdomain redirects
  to the apex (no stale-history tracking). This spec asserts the
  current behaviour: a former subdomain redirects to apex.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Agencies.HostResolver
  alias MarketMySpecSpex.Fixtures

  spex "visitor hits a previously-claimed subdomain after rename" do
    scenario "after Acme renames 'acme' to 'acme-co', visitor on acme.marketmyspec.com is redirected to apex" do
      given_ "Acme Marketing previously had subdomain 'acme', now has 'acme-co'", context do
        owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(owner)
        {:ok, agency} = HostResolver.claim_subdomain(agency, "acme")
        {:ok, _} = HostResolver.claim_subdomain(agency, "acme-co")

        {:ok, Map.put(context, :agency, agency)}
      end

      when_ "an unauthenticated visitor navigates to acme.marketmyspec.com/", context do
        visitor_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "acme.marketmyspec.com")

        response = get(visitor_conn, "/")

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is a redirect to the apex marketmyspec.com", context do
        assert context.response.status in 301..399,
               "expected a redirect status, got #{context.response.status}"

        location = get_resp_header(context.response, "location") |> List.first()

        assert is_binary(location),
               "expected a Location header on the redirect"

        assert location =~ "marketmyspec.com",
               "expected redirect target to point to marketmyspec.com, got: #{inspect(location)}"

        refute location =~ "acme.marketmyspec.com",
               "expected redirect target NOT to be the stale subdomain"

        {:ok, context}
      end
    end
  end
end
