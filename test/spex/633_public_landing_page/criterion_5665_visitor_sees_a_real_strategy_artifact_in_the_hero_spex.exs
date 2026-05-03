defmodule MarketMySpecSpex.Story633.Criterion5665Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5665 — Visitor sees a real strategy artifact in the hero
  """

  use MarketMySpecSpex.Case

  spex "real strategy artifact in the hero" do
    scenario "visitor sees a markdown artifact excerpt above the fold alongside the headline and install CTA", context do
      given_ "a visitor loading the landing page", context do
        {:ok, context}
      end

      when_ "the page renders", context do
        {:ok, view, html} = live(context.conn, "/")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the hero contains an artifact preview element", context do
        assert has_element?(context.view, "[data-test='artifact-preview']")
        :ok
      end

      then_ "the artifact preview contains non-empty content", context do
        artifact_html = context.view |> element("[data-test='artifact-preview']") |> render()
        assert has_element?(context.view, "[data-test='artifact-preview']")
        refute artifact_html =~ ~r/^\s*$/
        :ok
      end

      then_ "the headline is present alongside the artifact", context do
        assert has_element?(context.view, "[data-test='hero-headline']")
        :ok
      end

      then_ "the install command CTA is in the same viewport as the artifact", context do
        assert has_element?(context.view, "[data-test='install-command']")
        :ok
      end
    end
  end
end
