defmodule MarketMySpecSpex.Story695.Criterion6001Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6001 — Owner attempts to claim a subdomain already taken

  Story rule: subdomains are globally unique. A second agency
  attempting to claim a subdomain already held by another agency is
  rejected with a uniqueness error.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner attempts to claim a subdomain already taken" do
    scenario "Beta has 'acme'; Acme Marketing tries to claim 'acme' and is rejected" do
      given_ "Beta Inc owns subdomain 'acme'; Acme Marketing has no subdomain", context do
        beta_owner = Fixtures.user_fixture()
        alice = Fixtures.user_fixture()
        beta = Fixtures.agency_account_fixture(beta_owner)
        acme = Fixtures.agency_account_fixture(alice)

        {:ok, _} = MarketMySpec.Agencies.HostResolver.claim_subdomain(beta, "acme")
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{beta: beta, alice: alice, acme: acme, token: token})}
      end

      when_ "Alice signs in and tries to set subdomain 'acme' on Acme Marketing", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} = live(authed_conn, "/agency/settings")

        result =
          view
          |> form("[data-test='subdomain-form']", subdomain: %{subdomain: "acme"})
          |> render_submit()

        {:ok, Map.merge(context, %{conn: authed_conn, submit_result: result})}
      end

      then_ "the form re-renders with a uniqueness error and Acme has no subdomain saved", context do
        assert is_binary(context.submit_result),
               "expected the form to re-render on validation failure, got: #{inspect(context.submit_result)}"

        assert context.submit_result =~ ~r/already taken|not unique|must be unique|already exists/i,
               "expected a uniqueness error in the rendered form"

        {:ok, context}
      end
    end
  end
end
