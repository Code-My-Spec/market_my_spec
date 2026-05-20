defmodule MarketMySpecSpex.Story731.Criterion6474Spex do
  @moduledoc """
  Story 731 — 6474. Token is delivered to loopback callback, never
  rendered in browser. The rendered HTML at no point contains the
  issued token string.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "token is delivered to loopback callback, never rendered in browser" do
    scenario "approve completes; token appears only in the redirect URL" do
      given_ "an authenticated user on the pairing screen", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})

        {:ok, view, html_before} =
          live(conn, "/agents/pair?state=tok-#{System.unique_integer([:positive])}&port=51234&name=mac-mini")

        {:ok, Map.merge(context, %{view: view, html_before: html_before})}
      end

      when_ "the user clicks Approve", context do
        html_at_click = render(context.view)
        context.view |> element("[data-test='approve-pairing']") |> render_click()

        {url, _} = assert_redirect(context.view)
        %URI{query: q} = URI.parse(url)
        token = URI.decode_query(q || "") |> Map.fetch!("token")

        {:ok, Map.merge(context, %{token: token, html_at_click: html_at_click})}
      end

      then_ "no rendered HTML contained the issued token", context do
        refute context.html_before =~ context.token
        refute context.html_at_click =~ context.token
        {:ok, context}
      end
    end
  end
end
