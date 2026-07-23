defmodule MarketMySpecSpex.Story695.Criterion6013Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6013 — Visitor hits a never-claimed subdomain

  Story rule: a never-claimed subdomain redirects to the apex.
  """

  use MarketMySpecSpex.Case

  spex "visitor hits a never-claimed subdomain" do
    scenario "visitor on ghost.marketmyspec.com is redirected to apex" do
      given_ "no agency has ever claimed the subdomain 'ghost'", context do
        {:ok, context}
      end

      when_ "an unauthenticated visitor navigates to ghost.marketmyspec.com/", context do
        visitor_conn =
          Phoenix.ConnTest.build_conn()
          |> Map.put(:host, "ghost.marketmyspec.com")

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

        refute location =~ "ghost.marketmyspec.com",
               "expected redirect target NOT to be the unrecognized subdomain"

        {:ok, context}
      end
    end
  end
end
