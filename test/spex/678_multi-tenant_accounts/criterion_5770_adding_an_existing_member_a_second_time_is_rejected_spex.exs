defmodule MarketMySpecSpex.Story678.Criterion5770Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5770 — Adding an existing member a second time is rejected

  Story rule: a user holds exactly one role per account. Inviting the
  same email twice surfaces a conflict error and does not create a
  duplicate account_members record.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "adding an existing member a second time is rejected" do
    scenario "the second invite for the same email surfaces a conflict error" do
      given_ "a registered owner user", context do
        owner = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(owner)
        {:ok, Map.merge(context, %{owner: owner, owner_token: token})}
      end

      given_ "an existing member user", context do
        member = Fixtures.user_fixture()
        {:ok, Map.put(context, :member, member)}
      end

      when_ "the owner signs in and creates 'Duplicate Member Test'", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.owner_token}})

        {:ok, view, _html} = live(authed_conn, "/accounts/new")

        view
        |> form("[data-test='account-form']", account: %{name: "Duplicate Member Test"})
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the owner invites the member, then attempts to invite the same email again", context do
        {:ok, view, _html} = live(context.conn, ~p"/accounts")

        view
        |> form("[data-test='invite-member-form']",
          invitation: %{email: context.member.email, role: "member"}
        )
        |> render_submit()

        # Second invite for the same email
        second_html =
          view
          |> form("[data-test='invite-member-form']",
            invitation: %{email: context.member.email, role: "member"}
          )
          |> render_submit()

        {:ok, Map.put(context, :second_invite_html, second_html)}
      end

      then_ "the second invite renders a conflict error and is not silently accepted", context do
        assert context.second_invite_html =~
                 ~r/already (a member|invited|exists)|duplicate|conflict/i,
               "expected a conflict error on the second invite, got: #{String.slice(context.second_invite_html, 0, 300)}"

        refute context.second_invite_html =~ ~r/invitation sent/i,
               "expected no success confirmation for the duplicate invite"

        {:ok, context}
      end
    end
  end
end
