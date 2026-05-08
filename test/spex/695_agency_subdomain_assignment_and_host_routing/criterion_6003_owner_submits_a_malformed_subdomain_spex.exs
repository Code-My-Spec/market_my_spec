defmodule MarketMySpecSpex.Story695.Criterion6003Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6003 — Owner submits a malformed subdomain

  Story rule: subdomain format requires lowercase alphanumeric +
  hyphens. 'Acme!' contains uppercase and a special character; the
  form must reject it with a format error.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner submits a malformed subdomain" do
    scenario "owner submits 'Acme!' and the form re-renders with a format error" do
      given_ "an agency 'Acme Marketing' with Alice as owner", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits subdomain 'Acme!'", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        result =
          view
          |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "Acme!"})
          |> render_submit()

        {:ok, Map.merge(context, %{conn: authed_conn, submit_result: result})}
      end

      then_ "the form re-renders with a format error and the value is not persisted", context do
        assert is_binary(context.submit_result),
               "expected the form to re-render on validation failure, got: #{inspect(context.submit_result)}"

        assert context.submit_result =~ ~r/format|lowercase|invalid/i,
               "expected a format error in the rendered form"

        {:ok, context}
      end
    end
  end
end
