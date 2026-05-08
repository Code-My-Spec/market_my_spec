defmodule MarketMySpecSpex.Story684.Criterion5988Spex do
  @moduledoc """
  Story 684 — Browse and read account artifacts in a hierarchical files explorer
  Criterion 5988 — Switching accounts re-scopes the tree and clears stale selection.

  When the signed-in user switches the active account via the account
  picker, the explorer must reload the tree to show the new account's
  artifacts and any prior selection that no longer applies must be gone.

  The "switch" is driven through the real user surface: the account
  picker LiveView. After clicking a different account, returning to
  /files must reflect the new active_account_id.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.WriteFile
  alias MarketMySpecSpex.Fixtures

  spex "switching the active account from A to B re-scopes /files to show B's artifacts" do
    scenario "user with two accounts switches via the picker and the explorer reloads" do
      given_ "a user who is a member of two accounts, each with its own artifact", context do
        user = Fixtures.user_fixture()
        account_b = Fixtures.account_fixture(user, %{name: "Other Workspace"})

        scope_a = Fixtures.user_scope_fixture(user)
        scope_b = Map.put(scope_a, :active_account_id, account_b.id)

        frame_a = %{
          assigns: %{current_scope: scope_a},
          context: %{session_id: "spec-a-#{System.unique_integer([:positive])}"}
        }

        frame_b = %{
          assigns: %{current_scope: scope_b},
          context: %{session_id: "spec-b-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, _} =
          WriteFile.execute(
            %{path: "specs/alpha-auth.md", content: "# Alpha"},
            frame_a
          )

        {:reply, _, _} =
          WriteFile.execute(
            %{path: "specs/beta-billing.md", content: "# Beta"},
            frame_b
          )

        {:ok, Map.merge(context, %{user: user, account_b: account_b})}
      end

      when_ "the user signs in and opens an artifact under Account A (the default active)",
            context do
        {token, _raw} = Fixtures.generate_user_magic_link_token(context.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})
        {:ok, view_a, _html} = live(authed_conn, "/files/specs/alpha-auth.md")
        a_html = render(view_a)
        {:ok, Map.merge(context, %{conn: authed_conn, view_a: view_a, a_html: a_html})}
      end

      then_ "Account A's artifact renders", context do
        assert context.a_html =~ "Alpha"
        {:ok, context}
      end

      when_ "the user goes to the account picker and selects Account B", context do
        {:ok, picker_view, _html} = live(context.conn, "/accounts/picker")

        picker_view
        |> element(~s|[phx-value-account-id="#{context.account_b.id}"]|)
        |> render_click()

        {:ok, Map.put(context, :picker_view, picker_view)}
      end

      when_ "the user revisits /files after the switch", context do
        {:ok, view_b, _html} = live(context.conn, "/files")
        {:ok, Map.put(context, :view_b, view_b)}
      end

      then_ "the tree shows Account B's artifacts", context do
        html = render(context.view_b)
        assert html =~ "beta-billing.md"
        {:ok, context}
      end

      then_ "Account A's artifacts and prior selection are gone from the new view", context do
        html = render(context.view_b)
        assert html =~ "beta-billing.md"
        refute html =~ "alpha-auth.md"
        refute html =~ "Alpha"
        {:ok, context}
      end
    end
  end
end
