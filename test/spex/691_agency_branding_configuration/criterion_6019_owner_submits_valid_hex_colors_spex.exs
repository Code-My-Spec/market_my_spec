defmodule MarketMySpecSpex.Story691.Criterion6019Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6019 — Owner submits valid hex colors

  Story rule: primary and secondary colors must be valid 6-character
  hex codes in the form `#rrggbb`. Both `#22c55e` and `#1d4ed8` are
  accepted and persisted.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner submits valid hex colors" do
    scenario "valid #rrggbb values for primary and secondary are accepted and prefilled on reload" do
      given_ "an agency 'Acme Marketing' with Alice as owner", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits valid hex colors for primary and secondary", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        view
        |> form("[data-test='branding-form']",
          branding: %{primary_color: "#22c55e", secondary_color: "#1d4ed8"}
        )
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "the colors are accepted and prefilled on the form when reloaded", context do
        {:ok, view, html} = live(context.conn, "/agency/settings")

        assert has_element?(view, "[data-test='branding-form']"),
               "expected the branding form to render"

        assert html =~ "#22c55e",
               "expected primary_color to be prefilled with the saved value"

        assert html =~ "#1d4ed8",
               "expected secondary_color to be prefilled with the saved value"

        refute html =~ ~r/invalid color|must be #rrggbb|hex format/i,
               "expected no hex-format error after submitting valid colors"

        {:ok, context}
      end
    end
  end
end
