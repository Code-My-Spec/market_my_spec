defmodule MarketMySpecSpex.Story684.Criterion5986Spex do
  @moduledoc """
  Story 684 — Browse and read account artifacts in a hierarchical files explorer
  Criterion 5986 — Nested paths render as a navigable tree.

  Files at nested storage paths must surface as folder/leaf nodes in the
  left-pane tree. Each path segment is its own node — not flattened into a
  text label — so users can navigate the structure without guessing at paths.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.WriteFile
  alias MarketMySpecSpex.Fixtures

  spex "the left pane mirrors the storage hierarchy as a real tree" do
    scenario "files at nested paths show up as folder + leaf nodes the user can navigate" do
      given_ "a signed-in user with deeply nested artifacts", context do
        user = Fixtures.user_fixture()
        scope = Fixtures.user_scope_fixture(user)

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        for {path, body} <- [
              {"specs/auth/login.md", "# Login"},
              {"specs/auth/signup.md", "# Signup"},
              {"notes/launch.md", "# Launch"}
            ] do
          {:reply, _, _} = WriteFile.execute(%{path: path, content: body}, frame)
        end

        {:ok, Map.put(context, :user, user)}
      end

      when_ "the user opens the files explorer", context do
        {token, _raw} = Fixtures.generate_user_magic_link_token(context.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})
        {:ok, view, _html} = live(authed_conn, "/files")
        {:ok, Map.merge(context, %{conn: authed_conn, view: view})}
      end

      then_ "a tree container is present in the left pane", context do
        assert has_element?(context.view, "[data-test='file-tree']")
        {:ok, context}
      end

      then_ "top-level folders 'specs' and 'notes' each have their own folder node", context do
        assert has_element?(context.view, "[data-test='tree-folder-specs']")
        assert has_element?(context.view, "[data-test='tree-folder-notes']")
        {:ok, context}
      end

      then_ "the nested 'auth' folder under 'specs' is its own node, not flattened into a label",
            context do
        assert has_element?(
                 context.view,
                 "[data-test='tree-folder-specs/auth']"
               )

        {:ok, context}
      end

      then_ "leaf files appear as their own nodes under the nested folders", context do
        assert has_element?(
                 context.view,
                 "[data-test='tree-file-specs/auth/login.md']"
               )

        assert has_element?(
                 context.view,
                 "[data-test='tree-file-specs/auth/signup.md']"
               )

        assert has_element?(
                 context.view,
                 "[data-test='tree-file-notes/launch.md']"
               )

        {:ok, context}
      end
    end
  end
end
