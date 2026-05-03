defmodule MarketMySpecSpex.Story633.Criterion5674Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5674 — Equal-weight agency CTA next to install is rejected

  Quality gate: the install command is the primary CTA. The agency lane must be
  secondary and below the install — not placed at equal weight alongside it.
  """

  use MarketMySpecSpex.Case

  spex "agency CTA is secondary to the install command" do
    scenario "the agency CTA does not compete with the install command as an equal-weight primary CTA" do
      given_ "the landing page at its canonical route", context do
        {:ok, context}
      end

      when_ "the page is rendered", context do
        {:ok, view, _html} = live(context.conn, "/")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the install command is present as the primary CTA", context do
        assert has_element?(context.view, "[data-test='install-command']")
        {:ok, context}
      end

      then_ "the agency CTA is present but not inside a primary CTA group", context do
        assert has_element?(context.view, "[data-test='agency-cta']")
        refute has_element?(context.view, "[data-test='primary-cta-group'] [data-test='agency-cta']")
        {:ok, context}
      end

      then_ "no equal-weight hero CTA pair places the agency CTA alongside the install", context do
        assert has_element?(context.view, "[data-test='install-command']")
        refute has_element?(context.view, "[data-test='hero-cta-pair']")
        {:ok, context}
      end
    end
  end
end
