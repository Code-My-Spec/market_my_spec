defmodule MarketMySpecSpex.Story672.Criterion5682Spex do
  @moduledoc """
  Story 672 — Sign Up And Sign In With Google
  Criterion 5682 — Callback missing sub claim is rejected

  Quality gate: Google's `sub` is the stable account identifier. A token response
  without `sub` must be rejected — no integration is created or updated.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "callback missing sub claim is rejected" do
    scenario "OAuth callback with no sub claim results in an error, not a linked account", context do
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
        req_conn = get(context.conn, "/integrations/oauth/google")
        google_url = redirected_to(req_conn, 302)
        %{"state" => state} = google_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
        {:ok, Map.put(context, :oauth_state, state)}
      end

      when_ "Google returns a callback whose token response lacks a sub claim", context do
        Req.Test.stub(:google_oauth, fn conn ->
          case conn.request_path do
            "/token" -> 
              Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
                "access_token" => "test_access_token",
                "token_type" => "Bearer",
                "expires_in" => 3599
              }))

            _ ->
              Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
                "email" => "user@example.com",
                "name" => "Test User"
              }))
          end
        end)

        callback_conn =
          get(
            context.conn,
            "/integrations/oauth/callback/google?code=test_code&state=#{context.oauth_state}"
          )

        {:ok, Map.put(context, :callback_conn, callback_conn)}
      end

      then_ "the callback is rejected with an error flash", context do
        error_flash = get_flash(context.callback_conn, :error)
        assert error_flash, "expected an error flash to be set"
        assert error_flash =~ ~r/failed|error/i
        :ok
      end

      then_ "the user is not redirected to a success destination", context do
        error_flash = get_flash(context.callback_conn, :error)
        info_flash = get_flash(context.callback_conn, :info)
        assert error_flash, "anchor: error flash should be present"
        assert error_flash =~ ~r/failed|error/i
        refute info_flash && info_flash =~ ~r/connected/i
        :ok
      end
    end
  end
end
