defmodule MarketMySpecSpex.Story673.Criterion5687Spex do
  @moduledoc """
  Story 673 — Sign Up And Sign In With GitHub
  Criterion 5687 — User with private GitHub email still resolves consistently

  GitHub users can configure their email as private. When the callback returns
  a nil email, the account must still resolve using the stable GitHub user id.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "account resolves by GitHub id even when email is private" do
    scenario "user whose GitHub email is private still successfully connects" do
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

      when_ "GitHub returns a callback with a nil email but a valid user id", context do
        Req.Test.stub(:github_oauth, fn conn ->
          case conn.request_path do
            "/token" -> 
              Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
                "access_token" => "test_access_token",
                "token_type" => "bearer",
                "scope" => "user:email,read:user"
              }))

            _ ->
              Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
                "id" => 99_887_766,
                "login" => "devuser",
                "name" => "Dev User",
                "email" => nil,
                "avatar_url" => "https://avatars.githubusercontent.com/u/99887766"
              }))
          end
        end)

        callback_conn =
          get(
            context.conn,
            "/integrations/oauth/callback/github?code=test_code&state=#{context.oauth_state}"
          )

        {:ok, Map.put(context, :callback_conn, callback_conn)}
      end

      then_ "the integration is accepted despite the nil email", context do
        assert redirected_to(context.callback_conn, 302) =~ "/integrations"
        refute get_flash(context.callback_conn, :error)
        {:ok, context}
      end

      then_ "a success flash confirms the GitHub connection", context do
        info_flash = get_flash(context.callback_conn, :info)
        assert info_flash, "expected an info flash confirming the connection"
        assert info_flash =~ ~r/connected|GitHub/i
        {:ok, context}
      end
    end
  end
end
