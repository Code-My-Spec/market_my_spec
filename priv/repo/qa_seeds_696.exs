# QA seed script for Story 696 — Invite Members to an Account
#
# Run via:
#     mix run priv/repo/qa_seeds_696.exs
#
# Idempotent — safe to re-run. Prints credentials + URLs at the end.
#
# Creates:
#   - qa-owner@marketmyspec.test         — account owner (can invite, can manage)
#   - qa-member@marketmyspec.test        — member-role user (cannot invite)
#   - qa-existing@marketmyspec.test      — existing user (NOT a member) to test accept flow
#   - qa-owner's account                 — the account used for invitation tests
#
# Scenario seeds:
#   - A pending invitation to "pending-invite@example.com" (non-user, owner can see it)
#   - A pending invitation to qa-existing@marketmyspec.test (existing user, duplicate invite test)

alias MarketMySpec.Repo
alias MarketMySpec.Users
alias MarketMySpec.Users.{Scope, UserToken}
alias MarketMySpec.Accounts
alias MarketMySpec.Accounts.{Account, AccountsRepository, Member, Invitation}
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

  {encoded_token, user_token} = UserToken.build_email_token(user, "login")
  Repo.insert!(user_token)

  {user, encoded_token}
end

# ---------------------------------------------------------------------------
# Helper: ensure email has no membership in account (remove if present)
# ---------------------------------------------------------------------------
remove_membership_for_email = fn email, account_id ->
  user = Users.get_user_by_email(email)

  if user do
    member =
      Repo.one(
        from m in Member,
          where: m.account_id == ^account_id and m.user_id == ^user.id,
          limit: 1
      )

    if member, do: Repo.delete!(member)
  end
end

# ---------------------------------------------------------------------------
# Helper: reset invitations for email (decline accepted so we can re-invite)
# ---------------------------------------------------------------------------
reset_invitations_for_email = fn email, account_id ->
  Repo.update_all(
    from(i in Invitation,
      where:
        i.account_id == ^account_id and
          i.email == ^email and
          i.status == :accepted),
    set: [status: :declined]
  )
end

# ---------------------------------------------------------------------------
# User 1 — account owner (can invite)
# ---------------------------------------------------------------------------
{owner_user, owner_token} = upsert_user.("qa-owner@marketmyspec.test")

# Ensure owner has an individual account
owner_account =
  Repo.one(
    from a in Account,
      join: m in Member,
      on: m.account_id == a.id and m.user_id == ^owner_user.id and m.role == :owner,
      where: a.type == :individual,
      limit: 1
  )

owner_account =
  case owner_account do
    nil ->
      {:ok, acct} =
        AccountsRepository.create_account_with_owner(
          %{name: "QA Owner Account"},
          owner_user.id
        )

      acct

    existing ->
      existing
  end

# Update owner's active_account_id if not set
if owner_user.active_account_id != owner_account.id do
  Repo.update_all(
    from(u in Users.User, where: u.id == ^owner_user.id),
    set: [active_account_id: owner_account.id]
  )
end

# ---------------------------------------------------------------------------
# User 2 — member-role user (cannot invite)
# ---------------------------------------------------------------------------
{member_user, member_token} = upsert_user.("qa-member@marketmyspec.test")

# Ensure member_user is a member (not owner) of owner_account
existing_member =
  Repo.one(
    from m in Member,
      where: m.account_id == ^owner_account.id and m.user_id == ^member_user.id,
      limit: 1
  )

unless existing_member do
  Repo.insert!(%Member{
    account_id: owner_account.id,
    user_id: member_user.id,
    role: :member
  })
end

owner_scope = %Scope{user: owner_user, active_account_id: owner_account.id}

# ---------------------------------------------------------------------------
# User 3 — existing user (NOT a member) with a pending invitation
#           Used for: duplicate invite test (Criterion 6106), existing user accept (6111),
#           signed-in matching user accepts (6116), signed-in mismatched user blocked (6117)
# ---------------------------------------------------------------------------
{existing_user, existing_user_token} = upsert_user.("qa-existing@marketmyspec.test")

# Ensure qa-existing@marketmyspec.test is NOT a member of owner_account (so invites work)
remove_membership_for_email.("qa-existing@marketmyspec.test", owner_account.id)

# Reset accepted invitations for this user so we can re-invite
reset_invitations_for_email.("qa-existing@marketmyspec.test", owner_account.id)

# Cancel any existing pending invite so we can produce a fresh token on every seed run.
# (Tokens are hashed in the DB — the raw encoded_token is only available on the in-memory
# struct returned by Accounts.invite_user/4, never recoverable from a re-read.)
existing_user_invite =
  Repo.one(
    from i in Invitation,
      where:
        i.account_id == ^owner_account.id and
          i.email == ^existing_user.email and
          i.status == :pending,
      limit: 1
  )

if existing_user_invite do
  {:ok, _} = MarketMySpec.Accounts.InvitationRepository.cancel(owner_scope, existing_user_invite)
end

{:ok, existing_user_invitation} =
  Accounts.invite_user(owner_scope, owner_account.id, existing_user.email, :member)

existing_user_invite_token = existing_user_invitation.token

# ---------------------------------------------------------------------------
# "pending-invite@example.com" — generic pending invite for new-user accept test
#   After test scenarios, this user may have created an account, so we need
#   to also reset their membership and accepted invitations.
# ---------------------------------------------------------------------------

# Ensure pending-invite@example.com is NOT a member (reset for idempotency)
remove_membership_for_email.("pending-invite@example.com", owner_account.id)

# Reset accepted invitations for pending-invite@example.com so we can re-invite
reset_invitations_for_email.("pending-invite@example.com", owner_account.id)

# Same fresh-token strategy for pending-invite@example.com — cancel any pending,
# then re-invite so we can capture and print the raw token.
generic_invite_exists =
  Repo.one(
    from i in Invitation,
      where:
        i.account_id == ^owner_account.id and
          i.email == "pending-invite@example.com" and
          i.status == :pending,
      limit: 1
  )

if generic_invite_exists do
  {:ok, _} = MarketMySpec.Accounts.InvitationRepository.cancel(owner_scope, generic_invite_exists)
end

{:ok, generic_invitation} =
  Accounts.invite_user(owner_scope, owner_account.id, "pending-invite@example.com", :admin)

generic_invite_token = generic_invitation.token

# Reload owner_user to get updated active_account_id
owner_user = Users.get_user_by_email(owner_user.email)

IO.puts("""

QA SEED COMPLETE — Story 696: Invite Members to an Account
===========================================================

=== Owner (can invite, can manage) ===
Email:        #{owner_user.email}
User id:      #{owner_user.id}
Account:      #{owner_account.name} (#{owner_account.id})
Magic-link:   http://localhost:4008/users/log-in/#{owner_token}
Invitations:  http://localhost:4008/accounts/#{owner_account.id}/invitations

=== Member (cannot invite) ===
Email:        #{member_user.email}
User id:      #{member_user.id}
Magic-link:   http://localhost:4008/users/log-in/#{member_token}
Invitations:  http://localhost:4008/accounts/#{owner_account.id}/invitations

=== Existing User (has account, NOT a member, has pending invite) ===
Email:        #{existing_user.email}
User id:      #{existing_user.id}
Magic-link:   http://localhost:4008/users/log-in/#{existing_user_token}

=== Pending invitation tokens (raw, single-use, expire in 7 days) ===

Existing-user invite (#{existing_user.email}):
  http://localhost:4008/invitations/accept/#{existing_user_invite_token}

Generic invite (pending-invite@example.com):
  http://localhost:4008/invitations/accept/#{generic_invite_token}

Tokens are stored hashed in the DB; raw values above are only printable at create-time.
Re-run this seed to cancel + regenerate both invites with fresh tokens.
""")
