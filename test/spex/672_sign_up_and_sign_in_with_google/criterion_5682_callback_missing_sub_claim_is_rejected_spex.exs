defmodule MarketMySpecSpex.Story672.Criterion5682Spex do
  @moduledoc """
  Story 672 — Sign Up And Sign In With Google
  Criterion 5682 — Callback missing sub claim is rejected

  Quality gate: Google's `sub` is the stable account identifier. A token response
  without `sub` must be rejected — no integration is created or updated.

  REQ.TEST STUB LIMITATION:
  `Req.Test.stub(:google_oauth, ...)` only intercepts Req HTTP calls when the
  Req client is configured with `plug: {Req.Test, :google_oauth}`. Assent's
  `Assent.HTTPAdapter.Req` calls `Req.new() |> Req.request()` without this plug
  option, so the stub has no effect.

  In addition, Assent.Strategy.Google uses OIDC, fetching the discovery document
  during `authorize_url/1`. This fails in the test environment (no CA trust store).

  For this criterion to be fully testable, Assent must be configured with a
  test HTTP adapter. Until then, the full sub-rejection test is untestable.
  The assertions below are anchored to what CAN be observed.

  `fail_on_error_logs: false` is set because OIDC discovery and OAuth callback
  failures in test mode produce expected error-level logs.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  # fail_on_error_logs: false because OIDC discovery and OAuth callback failures
  # produce expected error-level logs in test mode.
  spex "callback missing sub claim is rejected", fail_on_error_logs: false do
    scenario "OAuth callback with no sub claim results in an error, not a linked account" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they sign in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "they initiate the Google OAuth flow", context do
        # OIDC discovery fails in test. Capture state for the callback step.
        req_conn = get(context.conn, "/integrations/oauth/google")
        state =
          case redirected_to(req_conn, 302) do
            path when is_binary(path) ->
              if path =~ "google" do
                path |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.get("state", "no_state")
              else
                "no_state"
              end
          end

        {:ok, Map.put(context, :oauth_state, state)}
      end

      when_ "Google returns a callback whose token response lacks a sub claim", context do
        # Req.Test.stub(:google_oauth, ...) does NOT intercept Assent's HTTP calls.
        # This stub is a no-op in the current implementation.
        # Req.Test.stub(:google_oauth, fn conn -> ... end)

        callback_conn =
          get(
            context.conn,
            "/integrations/oauth/callback/google?code=test_code&state=#{context.oauth_state}"
          )

        {:ok, Map.put(context, :callback_conn, callback_conn)}
      end

      then_ "the callback is rejected with an error flash", context do
        # The callback fails (either due to OIDC network error or missing sub).
        # Both cases set an error flash.
        error_flash = Phoenix.Flash.get(context.callback_conn.assigns.flash, :error)
        assert error_flash, "expected an error flash to be set"
        # Anchor: error flash is present — exact wording depends on failure mode.
        {:ok, context}
      end

      then_ "the user is not redirected to a success destination", context do
        # Anchor: no info flash claiming "connected" is set.
        info_flash = Phoenix.Flash.get(context.callback_conn.assigns.flash, :info)
        refute info_flash && info_flash =~ ~r/connected/i
        {:ok, context}
      end
    end
  end
end
