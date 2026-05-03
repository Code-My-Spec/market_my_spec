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

  # --- Session tokens -----------------------------------------------------
  #
  # Generates magic-link / session tokens server-side so specs can pre-auth
  # without round-tripping through the email outbox. The magic-link
  # confirmation flow itself is exercised by specs that drive
  # UserLive.Confirmation against the rendered link.

  defdelegate generate_user_magic_link_token(user), to: MarketMySpec.UsersFixtures

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
