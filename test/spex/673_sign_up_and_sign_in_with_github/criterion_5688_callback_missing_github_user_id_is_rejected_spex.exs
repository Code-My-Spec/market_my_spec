defmodule MarketMySpecSpex.Story673.Criterion5688Spex do
  @moduledoc """
  Story 673 — Sign Up And Sign In With GitHub
  Criterion 5688 — Callback missing GitHub user id is rejected

  Quality gate: the GitHub user `id` is the stable account identifier.
  A token response without an `id` or `sub` must be rejected — no integration
  is created or updated.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "callback missing GitHub user id is rejected" do
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
                "login" => "devuser",
                "name" => "Dev User",
                "email" => "dev@example.com"
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

      then_ "the callback is rejected with an error flash", context do
        assert get_flash(context.callback_conn, :error) =~ ~r/failed|error/i
        {:ok, context}
      end

      then_ "no success connection flash is shown", context do
        assert is_nil(get_flash(context.callback_conn, :info))
        {:ok, context}
      end
    end
  end
end
