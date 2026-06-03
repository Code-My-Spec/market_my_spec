defmodule MarketMySpecSpex.Story716.Criterion6464Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6464 — TouchpointLive.Show renders `polished_body` in an editable
  textarea (not readonly) with an explicit "Save" button; submitting calls
  `Engagements.update_touchpoint/3` and the persisted value matches what was
  submitted.

  Interaction surface: LiveView UI (operator surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements
  alias MarketMySpecSpex.Fixtures

  spex "polished_body is editable and Save persists the new value" do
    scenario "edit form submitted with a new body -> Engagements row updated" do
      given_ "a staged touchpoint with a body to edit", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "edit464"})

        touchpoint =
          Fixtures.touchpoint_fixture(scope, thread, %{polished_body: "Original body"})

        token = MarketMySpec.Users.generate_user_session_token(scope.user)

        conn =
          Phoenix.ConnTest.build_conn()
          |> Phoenix.ConnTest.init_test_session(%{})
          |> Plug.Conn.put_session(:user_token, token)

        {:ok, Map.merge(context, %{scope: scope, conn: conn, thread: thread, touchpoint: touchpoint})}
      end

      when_ "operator edits polished_body in the form and submits Save", context do
        path =
          "/app/accounts/#{context.scope.active_account_id}/touchpoints/#{context.touchpoint.id}"

        {:ok, view, html} = Phoenix.LiveViewTest.live(context.conn, path)

        refute html =~ ~s|<textarea[^>]*readonly[^>]*>Original body|,
               "expected polished_body textarea to NOT be readonly"

        new_body = "Edited polished body — final pass"

        view
        |> Phoenix.LiveViewTest.form("[data-test='edit-touchpoint-form']", %{
          "touchpoint" => %{"polished_body" => new_body, "angle" => context.touchpoint.angle || ""}
        })
        |> Phoenix.LiveViewTest.render_submit()

        {:ok, reloaded} = Engagements.get_touchpoint_by_id(context.scope, context.touchpoint.id)

        {:ok, Map.merge(context, %{new_body: new_body, reloaded: reloaded})}
      end

      then_ "the persisted polished_body matches the submitted value", context do
        assert context.reloaded.polished_body == context.new_body,
               "expected persisted polished_body to match submitted value; got: #{inspect(context.reloaded.polished_body)}"

        {:ok, context}
      end
    end
  end
end
