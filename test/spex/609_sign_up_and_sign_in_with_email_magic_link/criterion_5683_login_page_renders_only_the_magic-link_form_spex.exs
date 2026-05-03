defmodule MarketMySpecSpex.Story609.Criterion5683Spex do
  @moduledoc """
  Story 609 — Sign Up And Sign In With Email Magic Link
  Criterion 5683 — Login page renders only the magic-link form
  """

  use MarketMySpecSpex.Case

  spex "login page" do
    scenario "magic-link email form is the only authentication option shown" do
      given_ "an unauthenticated visitor", context do
        {:ok, context}
      end

      when_ "they navigate to the login page", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the magic-link email form is rendered with an email input", context do
        assert has_element?(context.view, "#login_form_magic")
        assert has_element?(context.view, "#login_form_magic input[type=email]")
        {:ok, context}
      end

      then_ "no password sign-in form is shown alongside it", context do
        # Anchor: confirm the page actually rendered its main content
        assert has_element?(context.view, "#login_form_magic")
        refute has_element?(context.view, "#login_form_password")
        {:ok, context}
      end
    end
  end
end
