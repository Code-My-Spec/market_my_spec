defmodule MarketMySpecSpex.Story691.Criterion6015Spex do
  @moduledoc """
  Story 691 — Agency Branding Configuration
  Criterion 6015 — Member-role user attempts to save branding

  Story rule: only agency members with `:manage_account` rights (owner
  or admin) can configure branding. A member-role user must not be able
  to save branding via the form — either the form's submit affordance
  is absent for them, or the route redirects them out before they can
  submit.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "member-role user attempts to save branding" do
    scenario "Bob, a member-role user of an agency, cannot save branding through the form" do
      given_ "an agency 'Acme Marketing' with Bob as a member-role user", context do
        alice = Fixtures.user_fixture()
        bob = Fixtures.user_fixture()
        agency = Fixtures.agency_account_fixture(alice)
        Fixtures.account_member_fixture(agency, bob, role: "member")
        {token, _raw} = Fixtures.generate_user_magic_link_token(bob)

        {:ok, Map.merge(context, %{alice: alice, bob: bob, agency: agency, token: token})}
      end

      when_ "Bob signs in and attempts to reach the branding form", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        result = live(authed_conn, "/agency/settings")

        {:ok, Map.merge(context, %{conn: authed_conn, mount_result: result})}
      end

      then_ "Bob is either redirected away or sees no submit affordance on the branding form", context do
        case context.mount_result do
          {:error, {:redirect, %{to: redirect_to}}} ->
            refute redirect_to =~ "/agency/settings",
                   "expected redirect to leave the branding route, got: #{inspect(redirect_to)}"

            {:ok, context}

          {:error, {:live_redirect, %{to: redirect_to}}} ->
            refute redirect_to =~ "/agency/settings",
                   "expected live_redirect to leave the branding route, got: #{inspect(redirect_to)}"

            {:ok, context}

          {:ok, view, _html} ->
            refute has_element?(view, "[data-test='branding-form'] button[type='submit']"),
                   "expected no submit button on the branding form for a member-role user"

            {:ok, context}
        end
      end
    end
  end
end
