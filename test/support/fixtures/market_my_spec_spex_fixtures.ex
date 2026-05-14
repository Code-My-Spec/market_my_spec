defmodule MarketMySpecSpex.Fixtures do
  @moduledoc """
  Curated bridge from BDD specs into in-app state.

  This is the **only** module inside the spex boundary that depends on
  `MarketMySpec` and `MarketMySpecTest`. Every export here is a sanctioned
  shortcut past the public LiveView / controller / MCP surface. Adding a
  function is a deliberate decision to expand what specs are allowed to
  reach — prefer driving the UI / hook flow that produces the state.

  **Rule of thumb:** Fixtures expose state that originates server-side
  (users, sessions, OAuth applications). State the user creates locally
  through the UI (their `marketing/` artifacts, their integration consent)
  must be driven through the LiveView or controller, not seeded here.
  """

  use Boundary, top_level?: true, deps: [MarketMySpec, MarketMySpecTest]

  # --- Sandbox ------------------------------------------------------------

  defdelegate setup_sandbox(tags), to: MarketMySpecTest.DataCase

  # --- Users --------------------------------------------------------------
  #
  # Server-side identity. Specs use these to set up an authenticated session
  # before driving the UI; the act-of-signing-in itself is exercised by
  # specs that drive UserLive.Login through the magic-link form.

  defdelegate user_fixture(attrs \\ %{}), to: MarketMySpec.UsersFixtures
  defdelegate unconfirmed_user_fixture(attrs \\ %{}), to: MarketMySpec.UsersFixtures
  defdelegate user_scope_fixture(), to: MarketMySpec.UsersFixtures
  defdelegate user_scope_fixture(user), to: MarketMySpec.UsersFixtures

  # --- Accounts -----------------------------------------------------------
  #
  # Admin-provisioned account types that cannot be created through the
  # self-service UI. Agency accounts are provisioned by admins only.

  defdelegate agency_account_fixture(user), to: MarketMySpec.UsersFixtures

  @doc """
  Creates an individual account owned by `user`. Accepts optional attrs map,
  e.g. %{name: "My Co"}.
  """
  defdelegate account_fixture(user, attrs \\ %{}), to: MarketMySpec.UsersFixtures

  # --- Agency-Client Grants -----------------------------------------------
  #
  # Fixtures for agency-client grant scenarios. These create database records
  # directly rather than driving the UI, as they represent server-side state
  # that BDD specs need as preconditions.

  @doc """
  Creates a client-originated (invited) grant with status="accepted".
  Pass access_level via keyword list, e.g. [access_level: "account_manager"].
  """
  defdelegate invited_grant_fixture(agency_account, client_account, attrs \\ []),
    to: MarketMySpec.UsersFixtures

  @doc """
  Creates a new client account and an agency-originated grant in one shot.
  Returns {client_account, grant}. Pass attrs map for client name, e.g. %{name: "Bright Co"}.
  """
  defdelegate originated_client_fixture(agency_account, attrs \\ %{}),
    to: MarketMySpec.UsersFixtures

  @doc """
  Adds `user` as a member of `account` with the given role.
  Pass role via keyword list, e.g. [role: "member"].
  """
  defdelegate account_member_fixture(account, user, opts \\ []), to: MarketMySpec.UsersFixtures

  @doc """
  Creates a registered user with a confirmed individual account and returns
  their Scope. Useful for specs that need an account-scoped user as a fixture.
  """
  defdelegate account_scoped_user_fixture(), to: MarketMySpec.UsersFixtures

  # --- Session tokens -----------------------------------------------------
  #
  # Generates magic-link / session tokens server-side so specs can pre-auth
  # without round-tripping through the email outbox. The magic-link
  # confirmation flow itself is exercised by specs that drive
  # UserLive.Confirmation against the rendered link.

  defdelegate generate_user_magic_link_token(user), to: MarketMySpec.UsersFixtures

  # --- Engagements --------------------------------------------------------
  #
  # Account-scoped Thread and Touchpoint preconditions for specs that drive
  # the stage_response MCP tool, the ThreadLive views, or the Posting
  # orchestrator. Threads default to source=:reddit; touchpoints default to
  # staged state (no comment_url / posted_at).

  defdelegate thread_fixture(scope), to: MarketMySpec.EngagementsFixtures
  defdelegate thread_fixture(scope, attrs), to: MarketMySpec.EngagementsFixtures

  defdelegate touchpoint_fixture(scope, thread), to: MarketMySpec.EngagementsFixtures
  defdelegate touchpoint_fixture(scope, thread, attrs), to: MarketMySpec.EngagementsFixtures

  # --- MCP tools (no fixture needed) --------------------------------------
  #
  # Specs drive MCP tools by calling the tool module's execute/2 callback
  # directly with a synthesized Anubis.Server.Frame carrying the scope.
  # No HTTP, no client, no fixture wrapper — just:
  #
  #     alias Anubis.Server.Frame
  #     alias MarketMySpec.McpServers.Marketing.Tools.InvokeSkill
  #
  #     frame = %Frame{assigns: %{current_scope: context.scope}}
  #     {:reply, response, _frame} =
  #       InvokeSkill.execute(%{skill_name: "marketing-strategy"}, frame)
  #
  # See `.code_my_spec/knowledge/bdd/spex/index.md` for the full pattern.
end
