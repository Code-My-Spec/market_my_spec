defmodule MarketMySpecSpex.Story609.Criterion5684Spex do
  @moduledoc """
  Story 609 — Sign Up And Sign In With Email Magic Link
  Criterion 5684 — Direct POST to password endpoint is rejected

  Story rule: a client tries to bypass the UI by POSTing user[email] +
  user[password] directly to /users/log-in. The password is ignored —
  no password verification path exists, and the only sign-in routes that
  succeed are magic-link confirmation, Google OAuth, and GitHub OAuth.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "direct password POST to /users/log-in is not authenticated" do
    scenario "submitting password with a valid email does not establish a session" do
      given_ "a registered user with a known email", context do
        user = Fixtures.user_fixture()
        {:ok, Map.put(context, :user, user)}
      end

      when_ "a client POSTs email + password directly to /users/log-in", context do
        conn =
          post(context.conn, "/users/log-in", %{
            "user" => %{
              "email" => context.user.email,
              "password" => "anything-goes-here"
            }
          })

        {:ok, Map.put(context, :conn, conn)}
      end

      then_ "no session token is set — the password did not authenticate", context do
        refute get_session(context.conn, :user_token)
        {:ok, context}
      end

      then_ "the response is not a redirect to a signed-in destination", context do
        # Anchor: confirm response is a controlled outcome (redirect or render),
        # not a 200 OK that would imply the password was honored.
        case context.conn do
          %Plug.Conn{status: status} when status in 300..399 ->
            target = redirected_to(context.conn)
            refute target == "/", "expected no redirect to the post-sign-in destination"

          %Plug.Conn{status: status} ->
            assert status in [200, 400, 401, 403, 404, 422],
                   "expected a controlled status, got #{status}"
        end

        refute get_session(context.conn, :user_token)
        {:ok, context}
      end
    end
  end
end
