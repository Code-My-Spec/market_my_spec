defmodule MarketMySpecSpex.Story672.Criterion5679Spex do
  @moduledoc """
  Story 672 — Sign Up And Sign In With Google
  Criterion 5679 — New visitor signs up via Google in one click
  """

  use MarketMySpecSpex.Case

  spex "new visitor signs up via Google in one click" do
    scenario "anonymous visitor sees Google sign-in on the login page and is redirected to Google", context do
      given_ "an anonymous visitor", context do
        :ok
      end

      when_ "they visit the login page", context do
        {:ok, view, html} = live(context.conn, "/users/log-in")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "a Google sign-in option is present on the login page", context do
        assert has_element?(context.view, "[data-test='google-sign-in']")
        :ok
      end

      when_ "they initiate the Google OAuth flow", context do
        req_conn = get(context.conn, "/integrations/oauth/google")
        {:ok, Map.put(context, :oauth_req_conn, req_conn)}
      end

      then_ "they are redirected to Google's authorization endpoint", context do
        redirect_url = redirected_to(context.oauth_req_conn, 302)
        assert redirect_url =~ "accounts.google.com"
        :ok
      end
    end
  end
end
