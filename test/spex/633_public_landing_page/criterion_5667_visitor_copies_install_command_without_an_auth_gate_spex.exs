defmodule MarketMySpecSpex.Story633.Criterion5667Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5667 — Visitor copies install command without an auth gate
  """

  use MarketMySpecSpex.Case

  spex "install command is immediately accessible with no auth gate" do
    scenario "visitor sees the install command and copy affordance before any sign-up prompt", context do
      given_ "an anonymous visitor on the landing page", context do
        {:ok, context}
      end

      when_ "they load the page", context do
        {:ok, view, html} = live(context.conn, "/")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the install command is rendered in a monospace block", context do
        assert has_element?(context.view, "[data-test='install-command']")
        assert context.html =~ "claude mcp add"
        :ok
      end

      then_ "a copy affordance is present alongside the install command", context do
        assert has_element?(context.view, "[data-test='copy-button']")
        :ok
      end

      when_ "they click the copy button", context do
        html = context.view |> element("[data-test='copy-button']") |> render_click()
        {:ok, Map.put(context, :after_copy_html, html)}
      end

      then_ "no sign-up modal or auth gate is presented", context do
        assert has_element?(context.view, "[data-test='install-command']")
        refute has_element?(context.view, "[data-test='auth-gate']")
        :ok
      end
    end
  end
end
