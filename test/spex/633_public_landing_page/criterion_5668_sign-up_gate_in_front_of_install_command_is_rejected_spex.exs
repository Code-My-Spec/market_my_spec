defmodule MarketMySpecSpex.Story633.Criterion5668Spex do
  @moduledoc """
  Story 633 — Public Landing Page
  Criterion 5668 — Sign-up gate in front of install command is rejected

  Quality gate: the install command must be fully visible and copyable without
  any authentication gate. If any auth-gate, email-capture form, or sign-up wall
  is present before the install command, this spec fails.
  """

  use MarketMySpecSpex.Case

  spex "no auth gate before the install command" do
    scenario "the deployed page exposes the install command without requiring sign-up", context do
      given_ "the landing page", context do
        {:ok, context}
      end

      when_ "it is rendered for an anonymous visitor", context do
        {:ok, view, html} = live(context.conn, "/")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the install command is present and not hidden behind an auth gate", context do
        assert has_element?(context.view, "[data-test='install-command']")
        refute has_element?(context.view, "[data-test='auth-gate']")
        :ok
      end

      then_ "no email-capture form appears before the install command", context do
        assert has_element?(context.view, "[data-test='install-command']")
        refute context.html =~ ~r/sign.?up to (get|see|access) the install/i
        :ok
      end

      then_ "the primary CTA is the install command, not a sign-up button", context do
        assert context.html =~ "claude mcp add"
        assert has_element?(context.view, "[data-test='install-command']")
        refute has_element?(context.view, "[data-test='signup-primary-cta']")
        :ok
      end
    end
  end
end
