defmodule MarketMySpecSpex.Story695.Criterion6009Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6009 — API call hits the apex domain

  Story rule: API endpoints (OAuth, MCP, .well-known) are served only
  on the apex. A GET to a public well-known endpoint on the apex must
  return 200 with the metadata payload.
  """

  use MarketMySpecSpex.Case

  spex "API call hits the apex domain" do
    scenario "well-known OAuth metadata is served on the apex" do
      given_ "an unauthenticated client conn pointed at the apex", context do
        api_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "marketmyspec.com")

        {:ok, Map.put(context, :api_conn, api_conn)}
      end

      when_ "the client GETs /.well-known/oauth-authorization-server", context do
        response = get(context.api_conn, "/.well-known/oauth-authorization-server")
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is 200 with a JSON OAuth metadata body", context do
        body = json_response(context.response, 200)

        assert is_map(body),
               "expected a JSON object body for OAuth authorization-server metadata"

        {:ok, context}
      end
    end
  end
end
