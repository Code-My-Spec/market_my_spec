defmodule MarketMySpecSpex.Story672.Criterion5681Spex do
  @moduledoc """
  Story 672 — Sign Up And Sign In With Google
  Criterion 5681 — User changes Google email and still resolves to the same MMS account

  The Google `sub` claim is the stable identifier. If a user changes their Google
  email, the account must resolve to the same MMS integration row and user.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "account resolves by Google sub even when email changes" do
    scenario "user whose Google email changed still resolves to their MMS account", context do
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

      when_ "Google returns a callback with a new email but the same sub", context do
        Req.Test.stub(:google_oauth, fn conn ->
          case conn.request_path do
            "/token" -> 
              Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
                "access_token" => "test_access_token",
                "token_type" => "Bearer",
                "expires_in" => 3599,
                "refresh_token" => "test_refresh_token"
              }))

            _ ->
              Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
                "sub" => "google_stable_sub_123",
                "email" => "changed_email@example.com",
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

      then_ "the integration is accepted and the user is redirected to integrations", context do
        assert redirected_to(context.callback_conn, 302) =~ "/integrations"
        error_flash = get_flash(context.callback_conn, :error)
        refute error_flash && error_flash =~ ~r/failed|error/i
        :ok
      end

      then_ "a success flash confirms the Google connection", context do
        info_flash = get_flash(context.callback_conn, :info)
        assert info_flash, "expected an info flash confirming the connection"
        assert info_flash =~ ~r/connected|Google/i
        :ok
      end
    end
  end
end
