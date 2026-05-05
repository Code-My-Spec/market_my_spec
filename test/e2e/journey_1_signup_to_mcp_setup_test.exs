defmodule MarketMySpecWeb.Journeys.Journey1SignupToMcpSetupTest do
  @moduledoc """
  Journey 1 — First-time founder lands, signs up, reaches MCP setup.

  Covers stories: 633 (Public Landing Page), 609 (Magic Link Sign-In),
  678 (Multi-Tenant Accounts), 611/634 (MCP Setup Guide).

  The registration flow (email delivery + link click) is covered by story 609 spex.
  Here we use a fixture-minted magic-link token to skip the email round-trip and
  focus on: landing page presence, sign-in, and /mcp-setup rendering.

  REQUIRES ChromeDriver: `brew install chromedriver`
  Run with: `mix test --include wallaby`
  """

  use MarketMySpecWeb.FeatureCase, async: false

  @moduletag :wallaby

  import Wallaby.Query

  feature "anonymous visitor lands on homepage and navigates to /mcp-setup after sign-in", %{
    session: session
  } do
    # Arrange: a confirmed user with a default individual account via fixture.
    user = user_fixture()
    {encoded_token, _raw} = generate_user_magic_link_token(user)

    # Step 1: Anonymous visitor opens / and sees the public landing page.
    session
    |> visit("/")
    |> assert_has(css("[data-test='hero-headline']"))
    |> assert_has(css("[data-test='byo-claude-benefit']"))
    |> assert_has(css("[data-test='agency-cta']"))
    |> assert_has(css("[data-test='install-command']"))

    # Steps 2–4: Sign in via magic-link token URL (skips email round-trip).
    # Visiting /users/log-in/:token renders the confirmation page; clicking
    # the submit button establishes an authenticated session via POST.
    session
    |> visit("/users/log-in/#{encoded_token}")
    |> click(css("button[type='submit']"))

    # Step 5: Navigate to /mcp-setup — all three steps and troubleshooting blocks must render.
    session
    |> visit("/mcp-setup")
    |> assert_has(css("[data-test='install-step']"))
    |> assert_has(css("[data-test='oauth-step']"))
    |> assert_has(css("[data-test='interview-step']"))
    |> assert_has(css("[data-test='expected-result']"))
    |> assert_has(css("[data-test='port-conflict-troubleshooting']"))
    |> assert_has(css("[data-test='oauth-troubleshooting']"))
    |> assert_has(css("[data-test='mcp-connection-troubleshooting']"))

    # Step 6: The install command is present and contains the expected prefix.
    install_text = Wallaby.Browser.text(session, css("[data-test='install-command']"))

    assert String.contains?(install_text, "claude mcp add market-my-spec"),
           "Expected install-command to contain 'claude mcp add market-my-spec', got: #{install_text}"
  end
end
