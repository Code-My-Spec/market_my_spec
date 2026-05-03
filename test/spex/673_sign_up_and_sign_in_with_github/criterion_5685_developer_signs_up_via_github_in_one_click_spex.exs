defmodule MarketMySpecSpex.Story673.Criterion5685Spex do
  @moduledoc """
  Story 673 — Sign Up And Sign In With GitHub
  Criterion 5685 — Developer signs up via GitHub in one click
  """

  use MarketMySpecSpex.Case

  spex "developer signs up via GitHub in one click" do
    scenario "anonymous visitor sees GitHub sign-in on the login page and is redirected to GitHub" do
      given_ "an anonymous visitor", context do
        {:ok, context}
      end

      when_ "they visit the login page", context do
        {:ok, view, html} = live(context.conn, "/users/log-in")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "a GitHub sign-in option is present on the login page", context do
        assert has_element?(context.view, "[data-test='github-sign-in']")
        {:ok, context}
      end

      when_ "they initiate the GitHub OAuth flow", context do
        req_conn = get(context.conn, "/integrations/oauth/github")
        {:ok, Map.put(context, :oauth_req_conn, req_conn)}
      end

      then_ "they are redirected to GitHub's authorization endpoint", context do
        redirect_url = redirected_to(context.oauth_req_conn, 302)
        assert redirect_url =~ "github.com"
        {:ok, context}
      end
    end
  end
end
