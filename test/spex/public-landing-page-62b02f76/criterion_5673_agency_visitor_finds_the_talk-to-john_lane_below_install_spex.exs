defmodule MarketMySpecSpex.Story633.Criterion5673Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5673 — Agency visitor finds the Talk-to-John lane below the install
  """

  use MarketMySpecSpex.Case

  spex "agency CTA is present below the install command" do
    scenario "agency visitor sees a Talk-to-John link on the landing page" do
      given_ "a visitor loading the landing page", context do
        {:ok, context}
      end

      when_ "the page renders", context do
        {:ok, view, _html} = live(context.conn, "/")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the agency CTA element is present on the page", context do
        assert has_element?(context.view, "[data-test='agency-cta']")
        {:ok, context}
      end

      then_ "the agency CTA contains copy directed at agencies", context do
        assert has_element?(context.view, "[data-test='agency-cta']")
        agency_html = context.view |> element("[data-test='agency-cta']") |> render()
        assert agency_html =~ ~r/run an agency/i
        assert agency_html =~ ~r/talk to john/i
        {:ok, context}
      end

      then_ "the install command is also present on the same page", context do
        assert has_element?(context.view, "[data-test='install-command']")
        assert has_element?(context.view, "[data-test='agency-cta']")
        {:ok, context}
      end
    end
  end
end
