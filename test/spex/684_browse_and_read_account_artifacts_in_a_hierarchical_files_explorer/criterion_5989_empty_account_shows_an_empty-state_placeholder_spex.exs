defmodule MarketMySpecSpex.Story684.Criterion5989Spex do
  @moduledoc """
  Story 684 — Browse and read account artifacts in a hierarchical files explorer
  Criterion 5989 — Empty account shows an empty-state placeholder.

  When the active account has zero artifacts, BOTH panes render empty-state
  placeholders side-by-side — left pane explains there are no artifacts, the
  right pane invites the user to select a file (when there are none yet).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "empty account shows side-by-side empty placeholders, not an error or blank screen" do
    scenario "user with no artifacts opens the files explorer" do
      given_ "a signed-in user whose active account has zero artifacts", context do
        user = Fixtures.user_fixture()
        {:ok, Map.put(context, :user, user)}
      end

      when_ "the user opens the files explorer", context do
        {token, _raw} = Fixtures.generate_user_magic_link_token(context.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})
        {:ok, view, _html} = live(authed_conn, "/files")
        {:ok, Map.merge(context, %{conn: authed_conn, view: view})}
      end

      then_ "the left pane shows the empty-state placeholder", context do
        assert has_element?(context.view, "[data-test='empty-state']")
        {:ok, context}
      end

      then_ "the right pane shows its own placeholder, not an error or blank screen",
            context do
        html = render(context.view)
        assert has_element?(context.view, "[data-test='file-pane']")
        assert has_element?(context.view, "[data-test='file-pane-empty']")
        refute has_element?(context.view, "[data-test='file-tree']")
        refute has_element?(context.view, "[data-test='file-content']")
        refute html =~ "Server error"
        refute html =~ "Internal Server Error"
        {:ok, context}
      end
    end
  end
end
