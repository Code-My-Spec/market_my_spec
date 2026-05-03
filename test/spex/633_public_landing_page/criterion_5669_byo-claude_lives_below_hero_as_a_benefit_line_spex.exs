defmodule MarketMySpecSpex.Story633.Criterion5669Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5669 — BYO-Claude lives below the hero as a benefit line
  """

  use MarketMySpecSpex.Case

  spex "BYO-Claude benefit line is present below the hero" do
    scenario "visitor sees the BYO-Claude benefit line after the hero section" do
      given_ "a visitor loading the landing page", context do
        {:ok, context}
      end

      when_ "the page renders", context do
        {:ok, view, html} = live(context.conn, "/")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the BYO-Claude benefit element is present on the page", context do
        assert has_element?(context.view, "[data-test='byo-claude-benefit']")
        {:ok, context}
      end

      then_ "the BYO-Claude benefit contains copy about token ownership", context do
        assert has_element?(context.view, "[data-test='byo-claude-benefit']")
        benefit_html = context.view |> element("[data-test='byo-claude-benefit']") |> render()
        assert benefit_html =~ ~r/bring your own claude/i
        assert benefit_html =~ ~r/don.t markup your tokens/i
        {:ok, context}
      end

      then_ "the install command is also present on the same page", context do
        assert has_element?(context.view, "[data-test='install-command']")
        assert has_element?(context.view, "[data-test='byo-claude-benefit']")
        {:ok, context}
      end
    end
  end
end
