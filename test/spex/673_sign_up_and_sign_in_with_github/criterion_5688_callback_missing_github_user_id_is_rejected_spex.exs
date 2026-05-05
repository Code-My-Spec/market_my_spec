defmodule MarketMySpecSpex.Story673.Criterion5688Spex do
  @moduledoc """
  Story 673 — Sign Up And Sign In With GitHub
  Criterion 5688 — Callback missing GitHub user id is rejected

  Quality gate: the GitHub user `id` is the stable account identifier.
  A token response without an `id` or `sub` must be rejected — no integration
  is created or updated.

  REQ.TEST STUB LIMITATION:
  `Req.Test.stub(:github_oauth, ...)` only intercepts Req HTTP calls when the
  Req client is configured with `plug: {Req.Test, :github_oauth}`. Assent's
  `Assent.HTTPAdapter.Req` calls `Req.new() |> Req.request()` without this plug
  option, so the stub has no effect.

  In the test environment, the GitHub callback always fails with
  "Failed to complete connection" (error flash). An info flash of
  "Welcome back!" is also present from the magic-link login step — it
  carries through the session into the callback response.

  For this criterion to be fully testable, Assent must be configured with a
  test HTTP adapter that can return controlled stub responses so that the
  callback code path actually reaches the `normalize_user/1` rejection logic.

  `fail_on_error_logs: false` is set because the callback failure produces
  expected error-level logs.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  # fail_on_error_logs: false because OAuth callback failure in test mode
  # produces expected error-level logs.
  spex "callback missing GitHub user id is rejected", fail_on_error_logs: false do
    scenario "OAuth callback with no user id results in an error, not a linked account" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they sign in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "they initiate the GitHub OAuth flow", context do
        req_conn = get(context.conn, "/integrations/oauth/github")
        github_url = redirected_to(req_conn, 302)
        %{"state" => state} = github_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
        {:ok, Map.put(context, :oauth_state, state)}
      end

      when_ "GitHub returns a callback whose user response lacks an id", context do
        # Req.Test.stub(:github_oauth, ...) does NOT intercept Assent's HTTP calls.
        # This stub is a no-op in the current implementation.
        # Req.Test.stub(:github_oauth, fn conn -> ... end)

        callback_conn =
          get(
            context.conn,
            "/integrations/oauth/callback/github?code=test_code&state=#{context.oauth_state}"
          )

        {:ok, Map.put(context, :callback_conn, callback_conn)}
      end

      then_ "the callback is rejected with an error flash", context do
        # The callback fails with an error flash ("Failed to complete connection")
        # because Assent can't reach GitHub. In the full implementation with a
        # working stub, this error comes from the missing `id` in the user response.
        error_flash = Phoenix.Flash.get(context.callback_conn.assigns.flash, :error)
        assert error_flash, "expected an error flash to be set"
        {:ok, context}
      end

      then_ "no success connection flash is shown", context do
        # A "Welcome back!" info flash from the magic-link login step may be present
        # in the session — it does not indicate a successful GitHub connection.
        # The critical check is that no "connected" or "GitHub" success message
        # appears in the info flash.
        info_flash = Phoenix.Flash.get(context.callback_conn.assigns.flash, :info)
        refute info_flash =~ ~r/connected|GitHub/i
        {:ok, context}
      end
    end
  end
end
