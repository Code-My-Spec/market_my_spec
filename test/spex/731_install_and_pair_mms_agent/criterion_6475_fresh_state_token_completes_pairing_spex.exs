defmodule MarketMySpecSpex.Story731.Criterion6475Spex do
  @moduledoc """
  Story 731 — 6475. Fresh state token (under 5 min) completes pairing.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "fresh state token completes pairing" do
    scenario "a brand-new state token completes pairing successfully" do
      given_ "an authenticated user opens /agents/pair with a fresh state", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})

        {:ok, view, _} =
          live(conn, "/agents/pair?state=fresh-#{System.unique_integer([:positive])}&port=51234&name=mac-mini")

        {:ok, Map.merge(context, %{view: view, user: user})}
      end

      when_ "the user clicks Approve", context do
        context.view |> element("[data-test='approve-pairing']") |> render_click()
        {url, _} = assert_redirect(context.view)
        {:ok, Map.put(context, :redirect, url)}
      end

      then_ "the redirect carries a non-empty token", context do
        %URI{query: q} = URI.parse(context.redirect)
        params = URI.decode_query(q || "")
        assert is_binary(params["token"]) and params["token"] != ""
        {:ok, context}
      end

      then_ "an Agent record exists for the user", context do
        assert Fixtures.list_paired_agents(context.user.id) != []
        {:ok, context}
      end
    end
  end
end
