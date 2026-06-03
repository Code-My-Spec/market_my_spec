# QA seed script for Story 743: Each pipeline stage persists a typed artifact
#
# Creates a QA user + OAuth application + bearer token for MCP testing.
# The bearer token is printed to stdout and used in curl calls against
# /mcp/problem-discovery.
#
# Usage:
#   mix run priv/repo/qa_seeds_743.exs
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
# 2. Ensure an OAuth application exists for QA
# ---------------------------------------------------------------------------
qa_app =
  case Repo.get_by(OauthApp, name: "qa-743") do
    nil ->
      uid = :crypto.strong_rand_bytes(16) |> Base.hex_encode32(padding: false) |> String.downcase()
      secret = :crypto.strong_rand_bytes(32) |> Base.hex_encode32(padding: false) |> String.downcase()

      app =
        %OauthApp{}
        |> Ecto.Changeset.change(%{
          name: "qa-743",
          uid: uid,
          secret: secret,
          redirect_uri: "http://localhost:4007/mcp-setup",
          scopes: "read write"
        })
        |> Repo.insert!()

      IO.puts("  Created OAuth app: qa-743 (uid=#{app.uid})")
      app

    app ->
      IO.puts("  Found OAuth app: qa-743 (uid=#{app.uid})")
      app
  end

# ---------------------------------------------------------------------------
# 3. Mint a fresh bearer token valid for 8 hours
# ---------------------------------------------------------------------------
# Delete any old QA-743 tokens for this user+app pair
Repo.delete_all(
  from(t in AccessToken,
    where: t.resource_owner_id == ^qa_user.id and t.application_id == ^qa_app.id
  )
)

{:ok, access_token} =
  ExOauth2Provider.AccessTokens.create_token(
    qa_user,
    %{
      "application" => qa_app,
      "use_refresh_token" => false,
      "expires_in" => 28_800
    },
    otp_app: :market_my_spec
  )

IO.puts("""

==========================================
 QA Seed Data — Story 743 MCP Credentials
==========================================

User:         qa@marketmyspec.test
Bearer token: #{access_token.token}
Expires in:   8 hours

MCP endpoint: http://localhost:4007/mcp/problem-discovery

Example curl (initialize):
  curl -sS -X POST http://localhost:4007/mcp/problem-discovery \\
    -H "Authorization: Bearer #{access_token.token}" \\
    -H "Content-Type: application/json" \\
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"qa","version":"1.0"}}}' | head -c 1000

==========================================
""")
