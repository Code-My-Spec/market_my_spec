defmodule MarketMySpecSpex.Story731.Criterion6472Spex do
  @moduledoc """
  Story 731 — criterion 6472. Authenticated user completes pairing.
  Surface: MarketMySpecWeb.AgentLive.Pair at /agents/pair.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "authenticated user completes pairing" do
    scenario "user approves and is redirected to the binary's localhost callback" do
      given_ "an authenticated user", context do
        user = Fixtures.user_fixture()
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => token}})
        {:ok, Map.merge(context, %{user: user, conn: conn})}
      end

      when_ "the agent opens /agents/pair with state, port, and name", context do
        url = "/agents/pair?state=#{state()}&port=51234&name=mac-mini"
        {:ok, view, html} = live(context.conn, url)
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the consent screen shows the agent name", context do
        assert context.html =~ "mac-mini"
        {:ok, context}
      end

      when_ "the user clicks Approve", context do
        context.view |> element("[data-test='approve-pairing']") |> render_click()
        {:ok, context}
      end

      then_ "the browser is redirected to http://localhost:51234/callback with a token", context do
        {url, _} = assert_redirect(context.view)
        assert String.starts_with?(url, "http://localhost:51234/callback")
        %URI{query: q} = URI.parse(url)
        params = URI.decode_query(q || "")
        assert params["token"] != nil and params["token"] != ""
        {:ok, context}
      end

      then_ "an Agent record was created for the user", context do
        assert Fixtures.list_paired_agents(context.user.id) != []
        {:ok, context}
      end
    end
  end

  defp state, do: "spex-#{System.unique_integer([:positive])}"
end
