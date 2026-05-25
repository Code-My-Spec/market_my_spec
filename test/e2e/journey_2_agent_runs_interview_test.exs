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
    session = log_in_via_magic_link(session, encoded_token)

    # Navigate to /files — the hierarchical tree explorer (story 684) lists
    # all 3 artifacts as file nodes under the "marketing" folder.
    session = visit(session, "/files")

    assert_has(session, css("[data-test='file-tree']"))
    assert_has(session, css("summary", text: "marketing"))
    assert_has(session, link("01_current_state.md"))
    assert_has(session, link("02_jobs_and_segments.md"))
    assert_has(session, link("03_personas.md"))

    # Click a file node — it patches to /files/<key> and renders the
    # markdown in the file-content pane.
    session
    |> click(link("01_current_state.md"))
    |> assert_has(css("[data-test='file-content']"))
  end
end
