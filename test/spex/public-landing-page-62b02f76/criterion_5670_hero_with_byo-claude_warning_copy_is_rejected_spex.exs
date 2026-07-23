defmodule MarketMySpecSpex.Story633.Criterion5670Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5670 — Hero with BYO-Claude warning copy is rejected

  Quality gate: BYO-Claude must be framed as a benefit, not a warning or caveat.
  Copy that sounds like a disclaimer in or near the hero fails this spec.
  """

  use MarketMySpecSpex.Case

  spex "BYO-Claude framing quality gate" do
    scenario "the deployed page frames BYO-Claude as a benefit, not a warning" do
      given_ "the landing page at its canonical route", context do
        {:ok, context}
      end

      when_ "the page is rendered", context do
        {:ok, view, _html} = live(context.conn, "/")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the BYO-Claude benefit element is present", context do
        assert has_element?(context.view, "[data-test='byo-claude-benefit']")
        {:ok, context}
      end

      then_ "the BYO-Claude copy does not frame it as a requirement or warning", context do
        benefit_html = context.view |> element("[data-test='byo-claude-benefit']") |> render()
        assert benefit_html =~ ~r/bring your own claude/i
        refute benefit_html =~ ~r/you must bring your own/i
        refute benefit_html =~ ~r/\brequired\b/i
        refute benefit_html =~ ~r/\bwarning\b/i
        {:ok, context}
      end

      then_ "the BYO-Claude element is not nested inside the hero section", context do
        benefit_html = context.view |> element("[data-test='byo-claude-benefit']") |> render()
        assert benefit_html =~ ~r/bring your own claude/i
        refute has_element?(context.view, "[data-test='hero-section'] [data-test='byo-claude-benefit']")
        {:ok, context}
      end
    end
  end
end
