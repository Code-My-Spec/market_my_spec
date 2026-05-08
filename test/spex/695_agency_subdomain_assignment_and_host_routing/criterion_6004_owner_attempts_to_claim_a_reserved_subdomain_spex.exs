defmodule MarketMySpecSpex.Story695.Criterion6004Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6004 — Owner attempts to claim a reserved subdomain

  Story rule: a reserved subdomain (admin, api, www, help, support,
  docs, blog) cannot be claimed.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner attempts to claim a reserved subdomain" do
    scenario "owner submits 'admin' and the form re-renders with a reserved-name error" do
      given_ "an agency 'Acme Marketing' with Alice as owner", context do
        alice = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, agency: agency, token: token})}
      end

      when_ "Alice signs in and submits subdomain 'admin'", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        result =
          view
          |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "admin"})
          |> render_submit()

        {:ok, Map.merge(context, %{conn: authed_conn, submit_result: result})}
      end

      then_ "the form re-renders with a reserved-name error", context do
        assert is_binary(context.submit_result),
               "expected the form to re-render on validation failure, got: #{inspect(context.submit_result)}"

        assert context.submit_result =~ ~r/reserved/i,
               "expected a reserved-name error in the rendered form"

        {:ok, context}
      end
    end
  end
end
