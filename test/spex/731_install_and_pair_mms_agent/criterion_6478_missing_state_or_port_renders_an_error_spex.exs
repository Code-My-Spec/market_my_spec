defmodule MarketMySpecSpex.Story731.Criterion6478Spex do
  @moduledoc """
  Story 731 — 6478. Missing state or port renders the invalid-link
  error and shows no Approve action.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  setup ctx do
    user = Fixtures.user_fixture()
    {tok, _} = Fixtures.generate_user_magic_link_token(user)
    conn = post(ctx.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
    {:ok, conn: conn}
  end

  spex "missing state or port renders an error" do
    scenario "no state param shows the invalid-link error" do
      when_ "the user opens /agents/pair without a state param", context do
        {:ok, _view, html} = live(context.conn, "/agents/pair?port=51234&name=mac-mini")
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the page renders the invalid-link error and no Approve", context do
        assert context.html =~ "Invalid pairing link"
        refute context.html =~ "approve-pairing"
        {:ok, context}
      end
    end

    scenario "no port param shows the invalid-link error" do
      when_ "the user opens /agents/pair without a port param", context do
        {:ok, _view, html} = live(context.conn, "/agents/pair?state=ABC&name=mac-mini")
        {:ok, Map.put(context, :html, html)}
      end

      then_ "the page renders the invalid-link error and no Approve", context do
        assert context.html =~ "Invalid pairing link"
        refute context.html =~ "approve-pairing"
        {:ok, context}
      end
    end
  end
end
