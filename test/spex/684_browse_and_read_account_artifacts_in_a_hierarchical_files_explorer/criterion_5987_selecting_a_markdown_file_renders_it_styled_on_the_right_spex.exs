defmodule MarketMySpecSpex.Story684.Criterion5987Spex do
  @moduledoc """
  Story 684 — Browse and read account artifacts in a hierarchical files explorer
  Criterion 5987 — Selecting a markdown file renders it styled on the right.

  Side-by-side contract: the user opens `/files`, sees the tree on the left,
  clicks a file in the tree, and the right pane updates with rendered
  markdown — without leaving the same page. Tree and content coexist on a
  single LiveView render.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.WriteFile
  alias MarketMySpecSpex.Fixtures

  @path "specs/auth.md"
  @body """
  # Auth Spec

  Some intro text.

  - bullet one
  - bullet two

  ```elixir
  IO.puts("hello")
  ```
  """

  spex "tree and rendered markdown coexist as left/right panes on /files" do
    scenario "clicking a leaf in the tree updates the right pane in place" do
      given_ "a signed-in user with a markdown artifact", context do
        user = Fixtures.user_fixture()
        scope = Fixtures.user_scope_fixture(user)

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, _} = WriteFile.execute(%{path: @path, content: @body}, frame)

        {:ok, Map.put(context, :user, user)}
      end

      when_ "the user signs in and opens /files", context do
        {token, _raw} = Fixtures.generate_user_magic_link_token(context.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})
        {:ok, view, _html} = live(authed_conn, "/files")
        {:ok, Map.merge(context, %{conn: authed_conn, view: view})}
      end

      then_ "both panes are present and the right pane prompts for selection",
            context do
        assert has_element?(context.view, "[data-test='file-tree']")
        assert has_element?(context.view, "[data-test='file-pane']")
        assert has_element?(context.view, "[data-test='file-pane-empty']")
        refute has_element?(context.view, "[data-test='file-content']")
        {:ok, context}
      end

      when_ "the user clicks the markdown file in the tree", context do
        context.view
        |> element("[data-test='tree-file-#{@path}']")
        |> render_click()

        {:ok, context}
      end

      then_ "the URL is at /files/<key> and the same LiveView is still mounted",
            context do
        assert_patched(context.view, "/files/" <> @path)
        assert has_element?(context.view, "[data-test='file-tree']")
        {:ok, context}
      end

      then_ "the right pane shows the rendered markdown content next to the tree",
            context do
        html = render(context.view)
        assert has_element?(context.view, "[data-test='file-content']")
        refute has_element?(context.view, "[data-test='file-pane-empty']")
        assert html =~ ~r/<h1[^>]*>\s*Auth Spec\s*<\/h1>/
        assert html =~ "<ul"
        assert html =~ "bullet one"
        assert html =~ "language-elixir"
        refute html =~ "```elixir"
        {:ok, context}
      end
    end
  end
end
