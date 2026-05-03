defmodule MarketMySpecSpex.Story609.Criterion5676Spex do
  @moduledoc """
  Story 609 — Sign Up And Sign In With Email Magic Link
  Criterion 5676 — Invalid email format is caught before submission
  """

  use MarketMySpecSpex.Case

  spex "sign up flow - email validation" do
    scenario "email without an @ sign shows a format error before the form submits" do
      given_ "a visitor on the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they type an email address that has no @ sign", context do
        html =
          context.view
          |> element("#registration_form")
          |> render_change(user: %{email: "notanemail"})

        {:ok, Map.put(context, :html, html)}
      end

      then_ "an inline format error is shown on the email field", context do
        assert context.html =~ "must have the @ sign and no spaces"
        {:ok, context}
      end

      then_ "the registration form is still visible so they can correct the input", context do
        assert has_element?(context.view, "#registration_form")
        {:ok, context}
      end
    end

    scenario "email with spaces shows a format error before the form submits" do
      given_ "a visitor on the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they type an email address containing spaces", context do
        html =
          context.view
          |> element("#registration_form")
          |> render_change(user: %{email: "bad email@example.com"})

        {:ok, Map.put(context, :html, html)}
      end

      then_ "an inline format error is shown on the email field", context do
        assert context.html =~ "must have the @ sign and no spaces"
        {:ok, context}
      end
    end
  end
end
