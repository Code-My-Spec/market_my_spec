defmodule MarketMySpecSpex.Story684.Criterion5984Spex do
  @moduledoc """
  Story 684 — Browse and read account artifacts in a hierarchical files explorer
  Criterion 5984 — Tree only contains the active account's artifacts.

  The contract under test: even when the signed-in user is a member of
  multiple accounts, the explorer only shows artifacts belonging to the
  account that is currently active. Membership alone does not grant
  visibility — `active_account_id` is the gate.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.WriteFile
  alias MarketMySpecSpex.Fixtures

  spex "files explorer is gated by active_account_id, not by membership" do
    scenario "user belonging to two accounts only sees the active account's artifacts" do
      given_ "a user who is a member of two accounts (A is active, B is not)", context do
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

        {:ok,
         Map.merge(context, %{
           user: user,
           account_b: account_b,
           scope_a: scope_a,
           scope_b: scope_b,
           frame_a: frame_a,
           frame_b: frame_b
         })}
      end

      given_ "both accounts have artifacts written by the user's agent", context do
        {:reply, _, _} =
          WriteFile.execute(
            %{path: "specs/alpha-auth.md", content: "# Alpha auth"},
            context.frame_a
          )

        {:reply, _, _} =
          WriteFile.execute(
            %{path: "notes/alpha-pricing.md", content: "# Alpha pricing"},
            context.frame_a
          )

        {:reply, _, _} =
          WriteFile.execute(
            %{path: "specs/beta-billing.md", content: "# Beta billing"},
            context.frame_b
          )

        {:ok, context}
      end

      when_ "the user signs in (Account A is active by default) and opens /files", context do
        {token, _raw} = Fixtures.generate_user_magic_link_token(context.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})
        {:ok, view, _html} = live(authed_conn, "/files")
        {:ok, Map.merge(context, %{conn: authed_conn, view: view})}
      end

      then_ "the explorer shows Account A's artifacts (active workspace)", context do
        html = render(context.view)
        assert html =~ "alpha-auth.md"
        assert html =~ "alpha-pricing.md"
        {:ok, context}
      end

      then_ "the explorer hides Account B's artifacts even though the user is a member",
            context do
        html = render(context.view)
        assert html =~ "alpha-auth.md"
        refute html =~ "beta-billing.md"
        {:ok, context}
      end
    end
  end
end
