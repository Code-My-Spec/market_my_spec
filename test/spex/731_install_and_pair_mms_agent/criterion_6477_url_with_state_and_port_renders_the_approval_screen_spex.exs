defmodule MarketMySpecSpex.Story731.Criterion6477Spex do
  @moduledoc """
  Story 731 — 6477. URL with state + port + name renders the approval
  screen showing the agent name and Approve/Deny buttons.
  """
  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "URL with state and port renders the approval screen" do
    scenario "agent name renders with Approve and Deny actions" do
      given_ "an authenticated user", context do
        user = Fixtures.user_fixture()
        {tok, _} = Fixtures.generate_user_magic_link_token(user)
        conn = post(context.conn, ~p"/users/log-in", %{"user" => %{"token" => tok}})
        {:ok, Map.put(context, :conn, conn)}
      end

      when_ "they open /agents/pair?state=ABC&port=51234&name=mac-mini", context do
        {:ok, view, html} =
          live(context.conn, "/agents/pair?state=ABC-#{System.unique_integer([:positive])}&port=51234&name=mac-mini")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the agent name renders on the page", context do
        assert context.html =~ "mac-mini"
        {:ok, context}
      end

      then_ "an Approve button is present", context do
        assert has_element?(context.view, "[data-test='approve-pairing']")
        {:ok, context}
      end

      then_ "a Deny button is present", context do
        assert has_element?(context.view, "[data-test='deny-pairing']")
        {:ok, context}
      end
    end
  end
end
