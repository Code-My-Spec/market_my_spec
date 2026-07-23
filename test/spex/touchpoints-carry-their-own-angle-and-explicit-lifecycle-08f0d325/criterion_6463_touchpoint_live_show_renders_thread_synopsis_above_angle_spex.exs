defmodule MarketMySpecSpex.Story716.Criterion6463Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6463 — TouchpointLive.Show renders the parent thread's
  `synopsis` when present, displayed above the angle.

  Interaction surface: LiveView UI (operator surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "synopsis from parent thread renders on the Show page" do
    scenario "thread with synopsis -> mount Show -> synopsis appears in HTML" do
      given_ "a thread with a synopsis and a staged touchpoint", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "syn463",
            synopsis: "OP is asking whether to integrate Ash incrementally into Phoenix/Ecto."
          })

        touchpoint = Fixtures.touchpoint_fixture(scope, thread, %{angle: "intro spec-driven angle"})

        token = MarketMySpec.Users.generate_user_session_token(scope.user)

        conn =
          Phoenix.ConnTest.build_conn()
          |> Phoenix.ConnTest.init_test_session(%{})
          |> Plug.Conn.put_session(:user_token, token)

        {:ok, Map.merge(context, %{scope: scope, conn: conn, thread: thread, touchpoint: touchpoint})}
      end

      when_ "the operator opens the touchpoint Show page", context do
        path =
          "/app/accounts/#{context.scope.active_account_id}/touchpoints/#{context.touchpoint.id}"

        case Phoenix.LiveViewTest.live(context.conn, path) do
          {:ok, _view, html} ->
            {:ok, Map.put(context, :html, html)}

          {:error, reason} ->
            flunk("expected Show reachable at #{path}; got: #{inspect(reason)}")
        end
      end

      then_ "the synopsis text appears under the thread context section", context do
        assert context.html =~ "OP is asking whether to integrate Ash incrementally",
               "expected synopsis text in rendered HTML"

        assert context.html =~ ~s|data-test="touchpoint-thread-synopsis"|,
               "expected synopsis container with data-test attribute"

        {:ok, context}
      end
    end
  end
end
