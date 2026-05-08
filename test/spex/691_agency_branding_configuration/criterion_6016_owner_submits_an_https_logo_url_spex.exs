defmodule MarketMySpecSpex.Story691.Criterion6016Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6016 — Owner submits an HTTPS logo URL

  Story rule: the logo URL must be a valid HTTPS URL (format-validated,
  not fetched at save time). A well-formed `https://...` URL is
  accepted and persisted.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner submits an HTTPS logo URL" do
    scenario "valid HTTPS URL is accepted and is prefilled on the form when reloaded" do
      given_ "an agency 'Acme Marketing' with Alice as owner", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits the branding form with an HTTPS logo URL", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        result =
          view
          |> form("[data-test='branding-form']",
            branding: %{logo_url: "https://acme.example/logo.svg"}
          )
          |> render_submit()

        {:ok, Map.merge(context, %{conn: authed_conn, submit_result: result})}
      end

      then_ "the URL is accepted (no format error) and prefills the form on reload", context do
        # On accept, render_submit may either redirect (binary tuple
        # absent) or re-render the form with the saved value. Either
        # way, the next mount of the form must show the saved URL with
        # no validation error.
        {:ok, view, html} = live(context.conn, "/agency/settings")

        assert has_element?(view, "[data-test='branding-form']"),
               "expected the branding form to render"

        assert html =~ "https://acme.example/logo.svg",
               "expected logo_url to be prefilled with the saved HTTPS URL"

        refute html =~ ~r/must be HTTPS|invalid url|must be a valid url/i,
               "expected no URL-format error after submitting a valid HTTPS URL"

        {:ok, context}
      end
    end
  end
end
