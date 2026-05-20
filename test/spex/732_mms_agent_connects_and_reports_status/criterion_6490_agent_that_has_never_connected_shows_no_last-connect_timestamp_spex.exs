defmodule MarketMySpecSpex.Story732.Criterion6490Spex do
  @moduledoc """
  Story 732 — 6490. Agent that has never connected shows no
  last-connect timestamp on the Agents page.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "agent that has never connected shows no last-connect timestamp" do
    scenario "a paired but never-joined agent renders without a last-connect value" do
      given_ "a user with a paired (never-connected) agent", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {_agent, _token} = Fixtures.pair_via_ui(conn, user, name: "never-connected")
        {:ok, Map.put(context, :conn, conn)}
      end

      when_ "the user visits /agents", context do
        {:ok, _view, html} = live(context.conn, "/agents")
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the never-connected agent renders the never-connected placeholder", context do
        assert context.html =~ "never-connected"
        assert context.html =~ ~r/never connected|—|Not yet connected/i
        {:ok, context}
      end
    end
  end
end
