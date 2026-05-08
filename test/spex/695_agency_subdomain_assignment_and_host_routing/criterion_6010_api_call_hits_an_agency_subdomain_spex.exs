defmodule MarketMySpecSpex.Story695.Criterion6010Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6010 — API call hits an agency subdomain

  Story rule: API endpoints are apex-only. A GET to a well-known
  endpoint on an agency subdomain must NOT be served as an API call —
  the host plug should redirect to apex (or return 404 for that path).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Agencies.HostResolver
  alias MarketMySpecSpex.Fixtures

  spex "API call hits an agency subdomain" do
    scenario "well-known endpoint on acme.marketmyspec.com is not served as API" do
      given_ "Acme Marketing has subdomain 'acme'", context do
        owner = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(owner)
        {:ok, _} = HostResolver.claim_subdomain(agency, "acme")

        {:ok, Map.put(context, :agency, agency)}
      end

      when_ "a client GETs /.well-known/oauth-authorization-server on acme.marketmyspec.com", context do
        api_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "acme.marketmyspec.com")

        response = get(api_conn, "/.well-known/oauth-authorization-server")
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is NOT a 200 OAuth metadata payload", context do
        # Either 404, 302 redirect to apex, or 4xx — anything but a 200
        # JSON metadata response. Status 200 here would mean the host
        # plug is letting API endpoints through on subdomains.
        refute context.response.status == 200,
               "expected NOT 200 on a subdomain API request; got 200 (host plug isn't filtering API endpoints to apex)"

        {:ok, context}
      end
    end
  end
end
