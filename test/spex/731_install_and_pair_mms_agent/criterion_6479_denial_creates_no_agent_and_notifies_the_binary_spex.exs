defmodule MarketMySpecSpex.Story731.Criterion6479Spex do
  @moduledoc """
  Story 731 — 6479. Denial creates no Agent and notifies the binary
  by redirecting to the loopback callback with `denied=true`.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "denial creates no Agent and notifies the binary" do
    scenario "user clicks Deny on the approval screen" do
      given_ "an authenticated user on the pairing screen", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})

        {:ok, view, _} =
          live(conn, "/agents/pair?state=deny-#{System.unique_integer([:positive])}&port=51234&name=mac-mini")

        {:ok, Map.merge(context, %{view: view, user: user})}
      end

      when_ "the user clicks Deny", context do
        context.view |> element("[data-test='deny-pairing']") |> render_click()
        {url, _} = assert_redirect(context.view)
        {:ok, Map.put(context, :redirect, url)}
      end

      then_ "the browser is redirected to http://localhost:51234/callback?denied=true", context do
        assert String.starts_with?(context.redirect, "http://localhost:51234/callback")
        %URI{query: q} = URI.parse(context.redirect)
        params = URI.decode_query(q || "")
        assert params["denied"] == "true"
        refute Map.has_key?(params, "token")
        {:ok, context}
      end

      then_ "no Agent record was created for the user", context do
        assert Fixtures.list_paired_agents(context.user.id) == []
        {:ok, context}
      end
    end
  end
end
