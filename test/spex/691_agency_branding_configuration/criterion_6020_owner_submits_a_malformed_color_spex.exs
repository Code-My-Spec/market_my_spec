defmodule MarketMySpecSpex.Story691.Criterion6020Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6020 — Owner submits a malformed color

  Story rule: primary and secondary colors must be 6-character hex
  codes in the form `#rrggbb`. CSS color names ("blue"), 3-char
  shorthand ("#abc"), and short hex ("#12345") are all rejected with
  a hex-format error.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner submits a malformed color" do
    scenario "a CSS color name as the primary value is rejected with a hex-format error" do
      given_ "an agency 'Acme Marketing' with Alice as owner", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _raw} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits a CSS color name as the primary value", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        result =
          view
          |> form("[data-test='branding-form']", branding: %{primary_color: "blue"})
          |> render_submit()

        {:ok, Map.merge(context, %{conn: authed_conn, submit_result: result})}
      end

      then_ "the form re-renders with a hex-format error and does not save the value", context do
        assert is_binary(context.submit_result),
               "expected the form to re-render on validation failure, got: #{inspect(context.submit_result)}"

        assert context.submit_result =~ ~r/#rrggbb|hex|invalid color|must be a valid color/i,
               "expected a hex-format error in the rendered form"

        {:ok, _view, html} = live(context.conn, "/agency/settings")

        refute html =~ ~r/value=['"]blue['"]/,
               "expected 'blue' to NOT be persisted as the prefilled primary_color"

        {:ok, context}
      end
    end
  end
end
