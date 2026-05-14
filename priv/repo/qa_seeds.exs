# QA seed script. Run via:
#
#     mix run priv/repo/qa_seeds.exs
#
# Idempotent — safe to re-run. Prints credentials + URLs at the end.
#
# Creates:
#   - qa@marketmyspec.test         — standard individual-account user (Journeys 1-3)
#   - qa-agency@marketmyspec.test  — agency-account owner (Journey 4 + Journey 5 agency side)
#   - qa-client@marketmyspec.test  — client-account owner (Journey 5 client side)
# Each gets a fresh magic-link token for direct sign-in.

alias MarketMySpec.Repo
alias MarketMySpec.Users
alias MarketMySpec.Accounts.{Account, AccountsRepository, Member}
import Ecto.Query

# ---------------------------------------------------------------------------
# Helper: upsert a user, force-confirm, mint a fresh magic-link token
# ---------------------------------------------------------------------------
upsert_user = fn email ->
  user =
    case Users.get_user_by_email(email) do
      nil ->
        {:ok, u} = Users.register_user(%{email: email})
        u
      existing ->
        existing
    end

  user =
    case user.confirmed_at do
      nil ->
        user
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update!()
      _confirmed ->
        user
    end

  {encoded_token, user_token} = MarketMySpec.Users.UserToken.build_email_token(user, "login")
  Repo.insert!(user_token)

  {user, encoded_token}
end

# ---------------------------------------------------------------------------
# User 1 — standard QA user (individual account, Journeys 1–3)
# ---------------------------------------------------------------------------
{qa_user, qa_token} = upsert_user.("qa@marketmyspec.test")

# ---------------------------------------------------------------------------
# User 2 — agency-account owner (Journey 4 and Journey 5 agency side)
# ---------------------------------------------------------------------------
{agency_user, agency_token} = upsert_user.("qa-agency@marketmyspec.test")

# Ensure agency user has an agency-typed account.
agency_account =
  Repo.one(
    from a in Account,
      join: m in Member,
      on: m.account_id == a.id and m.user_id == ^agency_user.id,
      where: a.type == :agency,
      limit: 1
  )

agency_account =
  case agency_account do
    nil ->
      {:ok, acct} =
        AccountsRepository.create_agency_account_with_owner(
          %{name: "QA Agency", type: :agency},
          agency_user.id
        )
      acct
    existing ->
      existing
  end

# ---------------------------------------------------------------------------
# User 3 — client-account owner (Journey 5 client side)
# ---------------------------------------------------------------------------
{client_user, client_token} = upsert_user.("qa-client@marketmyspec.test")

# Ensure the client user has an individual account.
client_account =
  Repo.one(
    from a in Account,
      join: m in Member,
      on: m.account_id == a.id and m.user_id == ^client_user.id,
      where: a.type == :individual,
      limit: 1
  )

client_account =
  case client_account do
    nil ->
      {:ok, acct} =
        AccountsRepository.create_account_with_owner(
          %{name: "QA Client Account"},
          client_user.id
        )
      acct
    existing ->
      existing
  end

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
endpoint_port =
  Application.get_env(:market_my_spec, MarketMySpecWeb.Endpoint, [])
  |> Keyword.get(:http, [])
  |> Keyword.get(:port, 4000)

base_url = "http://localhost:#{endpoint_port}"

IO.puts("""

QA SEED COMPLETE
================

=== Journey 1-3 user (individual account) ===
Email:        #{qa_user.email}
User id:      #{qa_user.id}
Magic-link:   #{base_url}/users/log-in/#{qa_token}

=== Journey 4 user (agency account owner) ===
Email:        #{agency_user.email}
User id:      #{agency_user.id}
Agency acct:  #{agency_account.name} (#{agency_account.id}) slug=#{agency_account.slug}
Magic-link:   #{base_url}/users/log-in/#{agency_token}

=== Journey 5 user (client account owner) ===
Email:        #{client_user.email}
User id:      #{client_user.id}
Client acct:  #{client_account.name} (#{client_account.id}) slug=#{client_account.slug}
Magic-link:   #{base_url}/users/log-in/#{client_token}

Tokens are single-use and expire in 20 minutes. Re-run to refresh.
""")
