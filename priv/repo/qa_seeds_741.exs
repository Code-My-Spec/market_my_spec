# QA seed script for Story 741: Red-team every surviving candidate from the same evidence
#
# Creates a QA user + OAuth application + bearer token for MCP testing.
# The bearer token is printed to stdout and used in curl calls against
# /mcp/problem-discovery.
#
# Usage:
#   CLOUDFLARE_TUNNEL_SECRET="" mix run priv/repo/qa_seeds_741.exs
#
# Idempotent — safe to re-run. Mints a fresh bearer token each time.
# Prerequisite: qa_seeds.exs must have been run (creates qa@marketmyspec.test).

alias MarketMySpec.Repo
alias MarketMySpec.Users
alias MarketMySpec.Oauth.Application, as: OauthApp
alias MarketMySpec.Oauth.AccessToken

import Ecto.Query

# ---------------------------------------------------------------------------
# 1. Ensure the QA user exists and is confirmed
# ---------------------------------------------------------------------------
qa_user =
  case Users.get_user_by_email("qa@marketmyspec.test") do
    nil ->
      {:ok, u} = Users.register_user(%{email: "qa@marketmyspec.test"})
      IO.puts("  Created qa@marketmyspec.test")

      u
      |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update!()

    u ->
      IO.puts("  Found qa@marketmyspec.test (id=#{u.id})")

      case u.confirmed_at do
        nil ->
          u
          |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
          |> Repo.update!()

        _ ->
          u
      end
  end

# ---------------------------------------------------------------------------
# 2. Ensure exactly one OAuth application exists for QA-741
# ---------------------------------------------------------------------------
apps = Repo.all(from(a in OauthApp, where: a.name == "qa-741"))

qa_app =
  case apps do
    [] ->
      uid =
        :crypto.strong_rand_bytes(16) |> Base.hex_encode32(padding: false) |> String.downcase()

      secret =
        :crypto.strong_rand_bytes(32) |> Base.hex_encode32(padding: false) |> String.downcase()

      app =
        %OauthApp{}
        |> Ecto.Changeset.change(%{
          name: "qa-741",
          uid: uid,
          secret: secret,
          redirect_uri: "http://localhost:4007/mcp-setup",
          scopes: "read write"
        })
        |> Repo.insert!()

      IO.puts("  Created OAuth app: qa-741 (uid=#{app.uid})")
      app

    [app | rest] ->
      for dup <- rest do
        Repo.delete_all(from(t in AccessToken, where: t.application_id == ^dup.id))
        Repo.delete!(dup)
        IO.puts("  Removed duplicate app id=#{dup.id}")
      end

      IO.puts("  Found OAuth app: qa-741 (uid=#{app.uid})")
      app
  end

# ---------------------------------------------------------------------------
# 3. Mint a fresh bearer token via direct struct insert
# ExOauth2Provider validates tokens using: inserted_at + expires_in > now
# So we don't need expires_at (which is a custom field the app's changeset
# tries to put but is not in the DB schema or ExOauth2Provider's schema).
# ---------------------------------------------------------------------------
Repo.delete_all(
  from(t in AccessToken,
    where: t.resource_owner_id == ^qa_user.id and t.application_id == ^qa_app.id
  )
)

# Generate a URL-safe token (same as the app's generate_token/0 function)
token_value = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

token =
  %AccessToken{}
  |> Ecto.Changeset.change(%{
    token: token_value,
    scopes: "read write",
    expires_in: 28_800,
    resource_owner_id: qa_user.id,
    application_id: qa_app.id,
    previous_refresh_token: ""
  })
  |> Repo.insert!()

IO.puts("""

==========================================
 QA Seed Data — Story 741 MCP Credentials
==========================================

User:         qa@marketmyspec.test
Bearer token: #{token.token}
Expires in:   8 hours

MCP endpoint: http://localhost:4007/mcp/problem-discovery

==========================================
""")
