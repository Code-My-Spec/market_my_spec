defmodule MarketMySpecSpex.Story684.Criterion5990Spex do
  @moduledoc """
  Story 684 — Browse and read account artifacts in a hierarchical files explorer
  Criterion 5990 — Selecting a non-markdown file is undefined behavior.

  Rendering non-markdown files is out of scope for this story. The
  explorer must NOT carry a defensive fallback that renders non-markdown
  contents in a pre/code block — that's exactly the "graceful handling"
  the rule excludes. Acceptable outcomes are (a) a process crash that
  the supervisor recovers, or (b) the page renders without showing the
  file body and without invoking the markdown pipeline.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.WriteFile
  alias MarketMySpecSpex.Fixtures

  @path "data/blob.json"
  @body ~s({"signal": "must-not-render"})

  spex "non-markdown selection has no defensive fallback rendering" do
    scenario "selecting a JSON artifact does not show its body and does not use the markdown pipeline" do
      given_ "a signed-in user with a non-markdown artifact", context do
        user = Fixtures.user_fixture()
        scope = Fixtures.user_scope_fixture(user)

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, _} = WriteFile.execute(%{path: @path, content: @body}, frame)

        {:ok, Map.put(context, :user, user)}
      end

      when_ "the user signs in and navigates to the non-markdown artifact", context do
        {token, _raw} = Fixtures.generate_user_magic_link_token(context.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        outcome =
          try do
            {:ok, view, _html} = live(authed_conn, "/files/" <> @path)
            {:rendered, render(view)}
          rescue
            _ -> {:crashed, :error}
          catch
            kind, _reason -> {:crashed, kind}
          end

        {:ok, Map.merge(context, %{conn: authed_conn, outcome: outcome})}
      end

      then_ "either a crash happened (acceptable) or no defensive fallback rendered the body",
            context do
        case context.outcome do
          {:crashed, _} ->
            {:ok, context}

          {:rendered, html} ->
            refute html =~ "must-not-render"
            refute html =~ ~r/<article[^>]*class=["'][^"']*prose/
            {:ok, context}
        end
      end
    end
  end
end
