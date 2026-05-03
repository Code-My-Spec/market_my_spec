# QA seed script. Run via:
#
#     mix run priv/repo/qa_seeds.exs
#
# Idempotent — safe to re-run. Prints credentials + URLs at the end.

alias MarketMySpec.Repo
alias MarketMySpec.Users

email = "qa@marketmyspec.test"

user =
  case Users.get_user_by_email(email) do
    nil ->
      {:ok, u} = Users.register_user(%{email: email})
      u

    existing ->
      existing
  end

# Force-confirm the user (skip the magic-link confirmation step) so QA
# tooling can sign them in without going through email.
user =
  case user.confirmed_at do
    nil ->
      user
      |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update!()

    _confirmed ->
      user
  end

# Generate a magic-link token QA can use to sign in via
# /users/log-in/:token without waiting for an email.
{encoded_token, user_token} = MarketMySpec.Users.UserToken.build_email_token(user, "login")
Repo.insert!(user_token)

IO.puts("""

QA SEED COMPLETE
================
User email:           #{user.email}
User id:              #{user.id}
Confirmed at:         #{user.confirmed_at}
Magic-link sign-in:   http://localhost:4007/users/log-in/#{encoded_token}

Use the magic-link URL to sign the seeded user in directly.
The token is single-use and expires in 20 minutes.
""")
