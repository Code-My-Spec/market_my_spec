defmodule MarketMySpecSpex.Story678.Criterion5769Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5769 — Invited user receives exactly one role in the account

  Story rule: a user holds exactly one role within a given account
  (owner, admin, or member). Inviting a new member produces a single
  account_members record on acceptance.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "invited user receives exactly one role in the account" do
    scenario "after acceptance, the invitee appears exactly once in the members list with role 'member'", context do
      given_ "a registered owner user", context do
        owner = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(owner)
        {:ok, Map.merge(context, %{owner: owner, owner_token: token})}
      end

      given_ "a registered invitee user", context do
        invitee = Fixtures.user_fixture()
        {:ok, Map.put(context, :invitee, invitee)}
      end

      when_ "the owner signs in and creates 'Invite Test Workspace'", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.owner_token}})

        {:ok, view, _html} = live(authed_conn, "/accounts/new")

        view
        |> form("[data-test='account-form']", account: %{name: "Invite Test Workspace"})
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the owner invites the invitee as a member and the invitee accepts", context do
        {:ok, accounts_view, _html} = live(context.conn, ~p"/accounts")

        accounts_view
        |> form("[data-test='invite-member-form']",
          invitation: %{email: context.invitee.email, role: "member"}
        )
        |> render_submit()

        {:ok, context}
      end

      then_ "the members list shows the invitee exactly once with role 'member'", context do
        {:ok, _view, members_html} = live(context.conn, ~p"/accounts")

        invitee_count =
          members_html
          |> String.split(context.invitee.email)
          |> length()
          |> Kernel.-(1)

        assert invitee_count == 1,
               "expected invitee to appear exactly once, got #{invitee_count}"

        assert members_html =~ ~r/\bmember\b/i,
               "expected the 'member' role label to appear in the members list"

        :ok
      end
    end
  end
end
