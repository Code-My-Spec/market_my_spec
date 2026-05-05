defmodule MarketMySpecWeb.Journeys.Journey2AgentRunsInterviewTest do
  @moduledoc """
  Journey 2 — Agent connects, runs the marketing-strategy interview, artifacts surface in /files.

  Covers stories: 676 (Strategy Artifacts Saved), 683 (Agent File Tools Over MCP).

  This test focuses on the browser-side surface: an authenticated user sees their
  artifacts in /files and can open one. The MCP-tool side (write_file, list_files,
  read_file) is fully covered by story 683/676 spex. Here we seed artifacts directly
  via the Files context, mimicking what the agent would have written.

  REQUIRES ChromeDriver: `brew install chromedriver`
  Run with: `mix test --include wallaby`
  """

  use MarketMySpecWeb.FeatureCase, async: false

  @moduletag :wallaby

  import Wallaby.Query

  alias MarketMySpec.Files
  alias MarketMySpec.Users.Scope

  feature "user with seeded artifacts sees them in /files and can open one", %{
    session: session
  } do
    # Arrange: a confirmed user with a default account.
    user = user_fixture()
    {encoded_token, _raw} = generate_user_magic_link_token(user)

    # Seed 3 artifacts directly via the Files context — this is exactly what
    # the agent's write_file tool does under the hood.
    scope = Scope.for_user(user)

    {:ok, _} =
      Files.put(scope, "marketing/01_current_state.md", "# Current State\n\n$10k MRR")

    {:ok, _} =
      Files.put(scope, "marketing/02_jobs_and_segments.md", "# Jobs and Segments\n\nFounders")

    {:ok, _} =
      Files.put(scope, "marketing/03_personas.md", "# Personas\n\n- Goal: first 100 customers")

    # Sign in via magic-link token.
    session
    |> visit("/users/log-in/#{encoded_token}")
    |> click(css("button[type='submit']"))

    # Navigate to /files — all 3 artifact filenames must appear.
    session = visit(session, "/files")

    assert_has(session, css(".card-title", text: "01_current_state.md"))
    assert_has(session, css(".card-title", text: "02_jobs_and_segments.md"))
    assert_has(session, css(".card-title", text: "03_personas.md"))

    # Verify the skill group heading "Marketing strategy" is visible.
    assert_has(session, css("h3", text: "Marketing strategy"))

    # Click "Open" on the first artifact and verify the file show page renders content.
    session
    |> click(link("Open"))
    |> assert_has(css("article"))
  end
end
