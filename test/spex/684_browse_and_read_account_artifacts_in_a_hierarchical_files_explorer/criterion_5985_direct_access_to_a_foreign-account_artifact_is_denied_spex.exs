defmodule MarketMySpecSpex.Story684.Criterion5985Spex do
  @moduledoc """
  Story 684 — Browse and read account artifacts in a hierarchical files explorer
  Criterion 5985 — Direct access to a foreign-account artifact is denied.

  Even when the signed-in user has membership in the foreign account, a path
  that exists only under the *non-active* account's prefix must not render
  while a different account is active. The active_account_id is the gate;
  multi-account membership does not bypass it.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.WriteFile
  alias MarketMySpecSpex.Fixtures

  @foreign_path "specs/private-billing.md"
  @foreign_body "# Private billing\nshhh"

  spex "an artifact in a non-active account is not directly addressable" do
    scenario "loading the foreign-account path directly does not render its contents" do
      given_ "a user who is a member of two accounts (A active, B not)", context do
        user = Fixtures.user_fixture()
        account_b = Fixtures.account_fixture(user, %{name: "Other Workspace"})

        scope_a = Fixtures.user_scope_fixture(user)
        scope_b = Map.put(scope_a, :active_account_id, account_b.id)

        frame_b = %{
          assigns: %{current_scope: scope_b},
          context: %{session_id: "spec-b-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{user: user, frame_b: frame_b})}
      end

      given_ "Account B has an artifact at a known relative path", context do
        {:reply, _, _} =
          WriteFile.execute(
            %{path: @foreign_path, content: @foreign_body},
            context.frame_b
          )

        {:ok, context}
      end

      when_ "the user signs in (A is active) and tries to load that path directly", context do
        {token, _raw} = Fixtures.generate_user_magic_link_token(context.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})
        {:ok, view, _html} = live(authed_conn, "/files/" <> @foreign_path)
        {:ok, Map.merge(context, %{conn: authed_conn, view: view})}
      end

      then_ "the page rendered but the artifact body is not visible", context do
        html = render(context.view)
        assert has_element?(context.view, "[data-test='artifact-error']")
        refute html =~ "Private billing"
        refute html =~ "shhh"
        {:ok, context}
      end

      then_ "the user sees a not-found / unavailable indication via the error element",
            context do
        assert has_element?(
                 context.view,
                 "[data-test='artifact-error']",
                 ~r/not available|not found|unauthorized/i
               )

        {:ok, context}
      end
    end
  end
end
