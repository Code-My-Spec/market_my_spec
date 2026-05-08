defmodule MarketMySpecSpex.Story695.Criterion6007Spex do
  @moduledoc """
  Story 695 — Agency Subdomain Assignment and Host Routing
  Criterion 6007 — Member-role user attempts to change the subdomain

  Story rule: only `:manage_account` (owner/admin) can change the
  subdomain. A member-role user must be denied.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Agencies.HostResolver
  alias MarketMySpecSpex.Fixtures

  spex "member-role user attempts to change the subdomain" do
    scenario "Bob (member) tries to update the subdomain and is denied" do
      given_ "an agency 'Acme Marketing' with subdomain 'acme' and Bob as a member", context do
        owner = Fixtures.user_fixture()
        bob = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(owner)
        {:ok, _} = HostResolver.claim_subdomain(agency, "acme")
        Fixtures.account_member_fixture(agency, bob, role: "member")
        {token, _} = Fixtures.generate_user_magic_link_token(bob)

        {:ok, Map.merge(context, %{bob: bob, agency: agency, token: token})}
      end

      when_ "Bob signs in and attempts to reach the settings page", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        result = live(authed_conn, "/agency/settings")

        {:ok, Map.merge(context, %{conn: authed_conn, mount_result: result})}
      end

      then_ "Bob is either redirected away or sees no submit affordance for the subdomain form", context do
        case context.mount_result do
          {:error, {:redirect, %{to: redirect_to}}} ->
            refute redirect_to =~ "/agency/settings",
                   "expected redirect to leave the settings route, got: #{inspect(redirect_to)}"

            {:ok, context}

          {:error, {:live_redirect, %{to: redirect_to}}} ->
            refute redirect_to =~ "/agency/settings",
                   "expected live_redirect to leave the settings route, got: #{inspect(redirect_to)}"

            {:ok, context}

          {:ok, view, _html} ->
            refute has_element?(view, "[data-test='subdomain-form'] button[type='submit']"),
                   "expected no submit button on the subdomain form for a member-role user"

            {:ok, context}
        end
      end
    end
  end
end
