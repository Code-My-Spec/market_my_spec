defmodule MarketMySpecWeb.Journeys.Journey3IterationTest do
  @moduledoc """
  Journey 3 — Returning user iterates on existing strategy, edits a step.

  Covers stories: 674 (iteration mode), 676 (artifact persistence), 683 (edit_file gate).

  This test pre-seeds 3 artifacts in the user's account workspace (simulating a prior
  session), then verifies /files shows them and /files/<key> renders the markdown.
  The read-before-edit gate behavior is covered by story 683 spex (unit-level); here
  we verify the browser surface reflects persisted content correctly.

  REQUIRES ChromeDriver: `brew install chromedriver`
  Run with: `mix test --include wallaby`
  """

  use MarketMySpecWeb.FeatureCase, async: false

  @moduletag :wallaby

  import Wallaby.Query

  alias MarketMySpec.Files
  alias MarketMySpec.Users.Scope

  feature "user with 3 prior artifacts sees them in /files and /files/<key> renders the markdown", %{
    session: session
  } do
    # Arrange: a confirmed user with a default account and 3 pre-seeded artifacts.
    user = user_fixture()
    {encoded_token, _raw} = generate_user_magic_link_token(user)
    scope = Scope.for_user(user)

    # Seed the 3 artifacts that the prior session would have written.
    {:ok, _} =
      Files.put(scope, "marketing/01_current_state.md", "# Current State\n\n$10k MRR")

    {:ok, _} =
      Files.put(scope, "marketing/02_jobs_and_segments.md", "# Jobs and Segments\n\nFounders")

    {:ok, _} =
      Files.put(
        scope,
        "marketing/03_personas.md",
        "# Personas\n\n- Goal: get first 100 customers"
      )

    # Sign in.
    session = log_in_via_magic_link(session, encoded_token)

    # /files shows all 3 prior artifacts in the tree explorer (story 684).
    session = visit(session, "/app/files")

    assert_has(session, css("[data-test='file-tree']"))
    assert_has(session, link("01_current_state.md"))
    assert_has(session, link("02_jobs_and_segments.md"))
    assert_has(session, link("03_personas.md"))

    # Clicking the 03_personas node patches to its key and renders the
    # markdown body in the file-content pane.
    session
    |> click(link("03_personas.md"))
    |> assert_has(css("[data-test='file-content']"))
    |> assert_has(css("h1", text: "Personas"))
  end
end
