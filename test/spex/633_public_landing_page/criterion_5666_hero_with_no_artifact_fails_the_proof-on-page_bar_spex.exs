defmodule MarketMySpecSpex.Story633.Criterion5666Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5666 — Hero with no artifact fails the proof-on-page bar

  Quality gate: a hero that ships without a concrete strategy artifact fails the
  "real doc visible on the page" closing-criterion from 03_personas.md.
  This spec asserts the artifact element exists and is non-empty; if absent or
  blank, the build is considered unfit to ship.
  """

  use MarketMySpecSpex.Case

  spex "artifact-in-hero quality gate" do
    scenario "the deployed hero contains a visible strategy artifact", context do
      given_ "the landing page at its canonical route", context do
        {:ok, context}
      end

      when_ "the page is rendered", context do
        {:ok, view, _html} = live(context.conn, "/")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the artifact-preview element is present in the hero", context do
        assert has_element?(context.view, "[data-test='artifact-preview']")
        :ok
      end

      then_ "the artifact-preview element is not blank", context do
        artifact_html = context.view |> element("[data-test='artifact-preview']") |> render()
        assert has_element?(context.view, "[data-test='artifact-preview']")
        refute artifact_html =~ ~r/^\s*$/
        :ok
      end

      then_ "the artifact content reads as a real strategy document excerpt, not placeholder copy", context do
        artifact_html = context.view |> element("[data-test='artifact-preview']") |> render()
        assert artifact_html =~ ~r/(positioning|ICP|channel|strategy|founder)/i
        refute artifact_html =~ ~r/Lorem ipsum/i
        :ok
      end
    end
  end
end
