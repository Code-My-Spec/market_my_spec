defmodule MarketMySpecSpex.Story716.Criterion6465Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6465 — TouchpointLive.Show renders `angle` in an editable textarea
  with the same Save flow as `polished_body`; submitting persists the new
  angle via `Engagements.update_touchpoint/3`.

  Interaction surface: LiveView UI (operator surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements
  alias MarketMySpecSpex.Fixtures

  spex "angle is editable and Save persists the new value" do
    scenario "edit form submitted with a new angle -> Engagements row updated" do
      given_ "a staged touchpoint with an initial angle", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "edit465"})

        touchpoint =
          Fixtures.touchpoint_fixture(scope, thread, %{
            polished_body: "Body that stays the same",
            angle: "Original angle: harness eng angle"
          })

        token = MarketMySpec.Users.generate_user_session_token(scope.user)

        conn =
          Phoenix.ConnTest.build_conn()
          |> Phoenix.ConnTest.init_test_session(%{})
          |> Plug.Conn.put_session(:user_token, token)

        {:ok, Map.merge(context, %{scope: scope, conn: conn, thread: thread, touchpoint: touchpoint})}
      end

      when_ "operator edits angle in the form and submits Save", context do
        path =
          "/accounts/#{context.scope.active_account_id}/touchpoints/#{context.touchpoint.id}"

        {:ok, view, _html} = Phoenix.LiveViewTest.live(context.conn, path)

        new_angle = "Revised angle: harness as the missing layer"

        view
        |> Phoenix.LiveViewTest.form("[data-test='edit-touchpoint-form']", %{
          "touchpoint" => %{
            "polished_body" => context.touchpoint.polished_body,
            "angle" => new_angle
          }
        })
        |> Phoenix.LiveViewTest.render_submit()

        {:ok, reloaded} = Engagements.get_touchpoint_by_id(context.scope, context.touchpoint.id)

        {:ok, Map.merge(context, %{new_angle: new_angle, reloaded: reloaded})}
      end

      then_ "the persisted angle matches the submitted value", context do
        assert context.reloaded.angle == context.new_angle,
               "expected persisted angle to match submitted value; got: #{inspect(context.reloaded.angle)}"

        {:ok, context}
      end
    end
  end
end
