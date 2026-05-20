defmodule MarketMySpecSpex.Story731.Criterion6476Spex do
  @moduledoc """
  Story 731 — 6476. Stale or consumed state token is rejected.

  Tests the "consumed" branch by replaying an already-approved state.
  Time-based staleness is a server-clock concern proved by Pairing's
  unit tests; the surface assertion here is the user-visible behavior:
  unavailable message renders, no Approve action shown.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "stale or consumed state token is rejected" do
    scenario "reusing an already-approved state shows the unavailable message" do
      given_ "an authenticated user has just completed a pairing", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})

        state = "reused-#{System.unique_integer([:positive])}"
        url = "/agents/pair?state=#{state}&port=51234&name=mac-mini"

        {:ok, view, _} = live(conn, url)
        view |> element("[data-test='approve-pairing']") |> render_click()
        assert_redirect(view)

        {:ok, Map.merge(context, %{user: user, conn: conn, url: url})}
      end

      when_ "the same state token is opened a second time", context do
        {:ok, _view, html} = live(context.conn, context.url)
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the page renders the unavailable message", context do
        assert context.html =~ "Pairing session unavailable"
        {:ok, context}
      end

      then_ "no Approve action is shown", context do
        refute context.html =~ "approve-pairing"
        {:ok, context}
      end

      then_ "no additional Agent record was created", context do
        assert length(Fixtures.list_paired_agents(context.user.id)) == 1
        {:ok, context}
      end
    end
  end
end
