defmodule MarketMySpecSpex.Story695.Criterion6026Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6026 — Visitor hits an unrecognized subdomain

  Story rule: any unrecognized subdomain (one not currently claimed by
  an agency) redirects to the apex. The system does not maintain
  history of previously-claimed subdomains; "stale" and "never-claimed"
  are treated identically.
  """

  use MarketMySpecSpex.Case

  spex "visitor hits an unrecognized subdomain" do
    scenario "visitor on ghost.marketmyspec.com is redirected to the apex" do
      given_ "no agency currently claims the subdomain 'ghost'", context do
        {:ok, context}
      end

      when_ "an unauthenticated visitor navigates to ghost.marketmyspec.com/", context do
        visitor_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "ghost.marketmyspec.com")

        response = get(visitor_conn, "/")

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response redirects to the apex marketmyspec.com", context do
        assert context.response.status in 301..399,
               "expected a redirect status for an unrecognized subdomain, got #{context.response.status}"

        location = get_resp_header(context.response, "location") |> List.first()

        assert is_binary(location),
               "expected a Location header"

        assert location =~ "marketmyspec.com",
               "expected redirect target to be the apex, got: #{inspect(location)}"

        refute location =~ "ghost.marketmyspec.com",
               "expected redirect target NOT to be the original subdomain"

        {:ok, context}
      end
    end
  end
end
