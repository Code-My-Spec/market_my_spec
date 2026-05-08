defmodule MarketMySpecSpex.Story695.Criterion6027Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6027 — Visitor hits a former subdomain after the agency renamed

  Story rule: a former subdomain (one an agency previously held but has
  since changed away from) is treated identically to a never-claimed
  subdomain — both redirect to the apex. There is no special handling
  that distinguishes the former-subdomain case.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Agencies.HostResolver
  alias MarketMySpecSpex.Fixtures

  spex "visitor hits a former subdomain after the agency renamed" do
    scenario "after Acme renames 'acme' to 'acme-co', visitor on acme.marketmyspec.com is redirected to apex (same path as never-claimed)" do
      given_ "Acme Marketing previously had subdomain 'acme', now has 'acme-co'; no other agency claims 'acme'", context do
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

      then_ "the response redirects to the apex (same as a never-claimed subdomain)", context do
        assert context.response.status in 301..399,
               "expected a redirect status, got #{context.response.status}"

        location = get_resp_header(context.response, "location") |> List.first()

        assert is_binary(location),
               "expected a Location header"

        assert location =~ "marketmyspec.com",
               "expected redirect target to be the apex, got: #{inspect(location)}"

        refute location =~ "acme.marketmyspec.com",
               "expected redirect target NOT to be the former subdomain"

        {:ok, context}
      end
    end
  end
end
