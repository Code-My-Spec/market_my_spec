defmodule MarketMySpecSpex.Story691.Criterion6014Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6014 — Owner saves all three branding fields

  Story rule: an agency member with `:manage_account` rights (owner or
  admin) can configure the agency's logo URL, primary color, and
  secondary color. Saved values persist and are visible on a
  subsequent mount of the form.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner saves all three branding fields" do
    scenario "owner submits logo URL, primary, and secondary; values are persisted and prefilled on reload" do
      given_ "an agency 'Acme Marketing' with no branding configured and Alice as owner", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits the branding form with all three values", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        view
        |> form("[data-test='branding-form']",
          branding: %{
            logo_url: "https://acme.example/logo.svg",
            primary_color: "#22c55e",
            secondary_color: "#1d4ed8"
          }
        )
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the saved values are prefilled on the form when reloaded", context do
        {:ok, view, html} = live(context.conn, "/agency/settings")

        assert has_element?(view, "[data-test='branding-form']"),
               "expected the branding form to render after save"

        assert html =~ "https://acme.example/logo.svg",
               "expected logo_url to be prefilled with the saved URL"

        assert html =~ "#22c55e",
               "expected primary_color to be prefilled with the saved value"

        assert html =~ "#1d4ed8",
               "expected secondary_color to be prefilled with the saved value"

        {:ok, context}
      end
    end
  end
end
