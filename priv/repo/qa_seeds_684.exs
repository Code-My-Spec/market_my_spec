# QA seed script for Story 684 — files explorer.
#
# Run via:
#
#     mix run priv/repo/qa_seeds_684.exs
#
# Idempotent. Drops a small fixed set of markdown artifacts (some nested,
# one non-markdown for the "out-of-scope" path) into the qa user's account
# workspace via the Files context, plus a known-but-different account so
# the cross-account scoping rule is observable.
#
# Prerequisite: priv/repo/qa_seeds.exs has been run at least once so the
# qa users exist. This script runs it transitively if needed.
alias MarketMySpec.Repo
alias MarketMySpec.Files
alias MarketMySpec.Users
alias MarketMySpec.Users.Scope
alias MarketMySpec.Accounts.{Account, Member, AccountsRepository}
import Ecto.Query

ensure_user = fn email ->
  case Users.get_user_by_email(email) do
    nil ->
      {:ok, u} = Users.register_user(%{email: email})

      u
      |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update!()

    existing ->
      existing
  end
end

mint_token = fn user ->
  {encoded, ut} = Users.UserToken.build_email_token(user, "login")
  Repo.insert!(ut)
  encoded
end

primary_account = fn user ->
  q =
    from a in Account,
      join: m in Member,
      on: m.account_id == a.id and m.user_id == ^user.id,
      where: a.type == :individual,
      order_by: a.inserted_at,
      limit: 1

  case Repo.one(q) do
    nil ->
      [local | _] = String.split(user.email, "@")
      name = "QA #{local} workspace"

      {:ok, acct} = AccountsRepository.create_account_with_owner(%{name: name}, user.id)

      acct

    existing ->
      existing
  end
end

# ----------------------------------------------------------------------
# Primary QA user — gets a populated workspace
# ----------------------------------------------------------------------
qa_user = ensure_user.("qa@marketmyspec.test")
qa_account = primary_account.(qa_user)
qa_token = mint_token.(qa_user)
qa_scope = %Scope{user: qa_user, active_account_id: qa_account.id}

# Second account for the same qa user — used to test the picker / switching rule.
qa_second_account =
  case Repo.one(
         from a in Account,
           join: m in Member,
           on: m.account_id == a.id and m.user_id == ^qa_user.id,
           where: a.name == "QA Secondary"
       ) do
    nil ->
      {:ok, acct} =
        AccountsRepository.create_account_with_owner(%{name: "QA Secondary"}, qa_user.id)

      acct

    existing ->
      existing
  end

qa_second_scope = %Scope{user: qa_user, active_account_id: qa_second_account.id}

# Pin the qa user's active account to the populated workspace so QA
# starts with a populated tree on /files. The picker rule is exercised
# explicitly via the secondary account.
qa_user
|> Ecto.Changeset.change(active_account_id: qa_account.id)
|> Repo.update!()

artifacts = [
  {"marketing/01_current_state.md", "# Current state\n\nWhere we are today."},
  {"marketing/02_jobs_and_segments.md", "# Jobs and segments\n\n- Job A\n- Job B\n"},
  {"marketing/research/personas.md", "# Personas\n\n## Solo founder\n\nDescription."},
  {"marketing/research/competitors.md", "# Competitors\n\n| Name | URL |\n|------|-----|\n"},
  {"specs/auth/login.md", "# Login spec\n\n```elixir\ndef login, do: :ok\nend\n```"},
  {"data/blob.json", ~s({"signal": "non-markdown — should not render"})}
]

for {path, body} <- artifacts do
  {:ok, _} = Files.put(qa_scope, path, body)
end

# A single distinctive file in the secondary account so the tester can see
# the tree change after switching.
{:ok, _} =
  Files.put(
    qa_second_scope,
    "notes/secondary-only.md",
    "# Secondary workspace\n\nThis only exists in the secondary account."
  )

# ----------------------------------------------------------------------
# Foreign QA user — gets ONE artifact under a different account so the
# cross-account scoping rule has something to refute against.
# ----------------------------------------------------------------------
foreign_user = ensure_user.("qa-foreign@marketmyspec.test")
foreign_account = primary_account.(foreign_user)
foreign_scope = %Scope{user: foreign_user, active_account_id: foreign_account.id}

{:ok, _} =
  Files.put(
    foreign_scope,
    "specs/private-billing.md",
    "# Private billing\n\nshhh — must not render in qa@marketmyspec.test's session."
  )

# ----------------------------------------------------------------------
# Empty-state user — gets no artifacts. Used to verify the empty placeholder.
# ----------------------------------------------------------------------
empty_user = ensure_user.("qa-empty@marketmyspec.test")
empty_account = primary_account.(empty_user)
empty_token = mint_token.(empty_user)

# ----------------------------------------------------------------------
# Output
# ----------------------------------------------------------------------
IO.puts("""

QA SEED 684 COMPLETE
====================

=== Populated user (use to test tree, markdown render, non-md crash, switching) ===
Email:       #{qa_user.email}
Primary acct:   #{qa_account.name} (#{qa_account.id})  [active by default]
Secondary acct: #{qa_second_account.name} (#{qa_second_account.id})  [switch via /accounts/picker]
Magic-link:  http://localhost:4008/users/log-in/#{qa_token}
Primary artifacts:
  - marketing/01_current_state.md
  - marketing/02_jobs_and_segments.md
  - marketing/research/personas.md
  - marketing/research/competitors.md
  - specs/auth/login.md
  - data/blob.json (non-markdown — selecting this should crash the LV)
Secondary artifact (only visible after switching to QA Secondary):
  - notes/secondary-only.md

=== Foreign-account user (don't sign in as this — its files prove cross-account scoping) ===
Account:     #{foreign_account.name} (#{foreign_account.id})
Foreign artifact: specs/private-billing.md (must NOT appear when signed in as qa user)

=== Empty user (use to test empty-state placeholder) ===
Email:       #{empty_user.email}
Account:     #{empty_account.name} (#{empty_account.id})
Magic-link:  http://localhost:4008/users/log-in/#{empty_token}

Backend in dev: MarketMySpec.Files.Disk — all files persist under tmp/files/.

Tokens are single-use; re-run this script to refresh.
""")
