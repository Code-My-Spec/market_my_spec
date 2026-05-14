defmodule MarketMySpecSpex.Story696.Criterion6117Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6117 — Signed-in mismatched user blocked

  When a signed-in user whose email does NOT match the invitation's email
  visits the accept page, the page renders the invitation card addressed
  to the invitee, surfaces a "wrong account" warning, and disables the
  accept button so the mismatched user cannot accept the invitation on
  the invitee's behalf — even if the invitee already has a user account.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Accounts.MembersRepository
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "signed-in mismatched user blocked", fail_on_error_logs: false do
    scenario "Dave is signed in but the accept page shows the invitation is for carol@example.com" do
      given_ "Alice's account has an invitation for carol@example.com, but Dave is signed in",
             context do
        alice = Fixtures.user_fixture()
        dave = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, invitation} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            "carol@example.com",
            :member
          )

        {dave_token, _} = Fixtures.generate_user_magic_link_token(dave)

        {:ok,
         Map.merge(context, %{
           alice: alice,
           dave: dave,
           account: account,
           invitation: invitation,
           dave_token: dave_token
         })}
      end

      when_ "Dave signs in and visits carol@example.com's invitation accept URL", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.dave_token}})

        {:ok, view, html} = live(authed_conn, "/invitations/accept/#{context.invitation.token}")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the accept page shows the invitation addressed to carol@example.com with a create account form",
            context do
        html = context.html

        # The invitation card's "To:" line must show the invitation's email
        assert html =~ "carol@example.com",
               "expected the accept page to display carol@example.com as the invitee"

        # Since carol has no account, the page must offer account creation — not the existing-user path
        assert html =~ "Create Your Account" or html =~ "Create Account",
               "expected the page to offer account creation since carol has no existing account"

        # The mismatch must be surfaced so Dave knows to log out
        assert html =~ "Wrong account",
               "expected the page to warn Dave that he is signed in as the wrong user"

        {:ok, context}
      end
    end

    scenario "Dave cannot accept carol@example.com's invitation even when carol already has an account" do
      given_ "Alice invited carol (who already has an account), and Dave is signed in",
             context do
        alice = Fixtures.user_fixture()
        carol = Fixtures.user_fixture(%{email: "carol@example.com"})
        dave = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, invitation} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            carol.email,
            :member
          )

        {dave_token, _} = Fixtures.generate_user_magic_link_token(dave)

        {:ok,
         Map.merge(context, %{
           alice: alice,
           carol: carol,
           dave: dave,
           account: account,
           invitation: invitation,
           dave_token: dave_token
         })}
      end

      when_ "Dave signs in and clicks Accept Invitation on carol's invite", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.dave_token}})

        {:ok, view, _html} = live(authed_conn, "/invitations/accept/#{context.invitation.token}")

        result = render_click(view, "accept_invitation", %{})

        {:ok, Map.merge(context, %{view: view, click_result: result})}
      end

      then_ "the accept event is refused and neither Dave nor carol is added to the account",
            context do
        # The accept button must be disabled when mismatched
        accept_html = render(context.view)

        assert accept_html =~ "Wrong account",
               "expected the mismatch warning to be rendered"

        assert accept_html =~ ~s(disabled),
               "expected the accept button to be disabled for a mismatched signed-in user"

        # Any click-through must result in a flash error, not acceptance
        assert context.click_result =~ "Sign out",
               "expected a flash error instructing Dave to sign out"

        # The invitation must remain pending
        refreshed = Repo.reload!(context.invitation)
        assert refreshed.status == :pending

        # Neither user may have been added as a member of Alice's account
        refute MembersRepository.user_has_account_access?(context.dave.id, context.account.id),
               "Dave must not have been added to Alice's account"

        refute MembersRepository.user_has_account_access?(context.carol.id, context.account.id),
               "Carol must not have been added to Alice's account via Dave's session"

        {:ok, context}
      end
    end
  end
end
