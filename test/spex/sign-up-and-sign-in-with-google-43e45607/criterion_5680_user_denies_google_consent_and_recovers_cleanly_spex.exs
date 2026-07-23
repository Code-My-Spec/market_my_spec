defmodule MarketMySpecSpex.Story672.Criterion5680Spex do
  @moduledoc """
  Story 672 — Sign Up And Sign In With Google
  Criterion 5680 — User denies Google consent and recovers cleanly

  ROUTE NOTE:
  The previous version of this criterion exercised
  `/integrations/oauth/callback/google` — the IntegrationsController route
  for an *already-authenticated* user adding a data-import integration.
  Story 672 is about *public sign-up/sign-in*, which lives at
  `/auth/google/callback` (UserOAuthController). The denial flash and
  recovery destination differ between the two flows; this criterion now
  asserts the public-flow behavior to match the story.
  """

  use MarketMySpecSpex.Case

  spex "user denies Google consent and recovers cleanly" do
    scenario "anonymous visitor who denies Google consent lands back on log-in with a clear error" do
      given_ "an anonymous visitor mid-OAuth", context do
        # Seed the session as `UserOAuthController.request/2` would have:
        # the controller stashes :sign_in_oauth_provider before redirecting
        # to Google; the callback reads and deletes it.
        conn =
          context.conn
          |> Plug.Test.init_test_session(%{})
          |> Plug.Conn.put_session(:sign_in_oauth_provider, :google)

        {:ok, Map.put(context, :conn, conn)}
      end

      when_ "Google returns an access_denied callback to the public sign-in route", context do
        callback_conn = get(context.conn, "/auth/google/callback?error=access_denied")
        {:ok, Map.put(context, :callback_conn, callback_conn)}
      end

      then_ "the user is redirected back to the log-in page so they can try again", context do
        assert redirected_to(context.callback_conn, 302) == "/users/log-in"
        {:ok, context}
      end

      then_ "an error flash explains the denial in user-friendly language", context do
        error_flash = Phoenix.Flash.get(context.callback_conn.assigns.flash, :error)

        assert error_flash, "expected an error flash to be set after access_denied"
        assert error_flash =~ ~r/denied|access/i,
               "expected the flash to mention the denial; got: #{inspect(error_flash)}"

        {:ok, context}
      end
    end
  end
end
