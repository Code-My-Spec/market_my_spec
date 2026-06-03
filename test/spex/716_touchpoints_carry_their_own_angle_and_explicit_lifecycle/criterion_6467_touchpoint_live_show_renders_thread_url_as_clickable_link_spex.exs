defmodule MarketMySpecSpex.Story716.Criterion6467Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6467 — TouchpointLive.Show renders the parent thread's `url` as a
  clickable anchor with `target="_blank"` and `rel="noopener noreferrer"`,
  positioned near the top of the page for quick navigation to the source
  platform.

  Interaction surface: LiveView UI (operator surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "parent thread URL renders as a target=_blank link" do
    scenario "mount Show -> anchor element with href matching thread.url + target/rel attributes" do
      given_ "a thread with a known URL and a staged touchpoint", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread_url = "https://www.reddit.com/r/elixir/comments/link467/test_thread"

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "link467",
            url: thread_url
          })

        touchpoint = Fixtures.touchpoint_fixture(scope, thread, %{})

        token = MarketMySpec.Users.generate_user_session_token(scope.user)

        conn =
          Phoenix.ConnTest.build_conn()
          |> Phoenix.ConnTest.init_test_session(%{})
          |> Plug.Conn.put_session(:user_token, token)

        {:ok,
         Map.merge(context, %{
           scope: scope,
           conn: conn,
           thread: thread,
           thread_url: thread_url,
           touchpoint: touchpoint
         })}
      end

      when_ "operator opens the touchpoint Show page", context do
        path =
          "/app/accounts/#{context.scope.active_account_id}/touchpoints/#{context.touchpoint.id}"

        case Phoenix.LiveViewTest.live(context.conn, path) do
          {:ok, _view, html} -> {:ok, Map.put(context, :html, html)}
          {:error, reason} -> flunk("Show unreachable: #{inspect(reason)}")
        end
      end

      then_ "the page contains an <a> with the thread URL, target=_blank, and rel=noopener noreferrer", context do
        html = context.html

        assert html =~ ~s|data-test="touchpoint-thread-link"|,
               "expected touchpoint-thread-link data-test attribute"

        assert html =~ ~s|href="#{context.thread_url}"|,
               "expected anchor href matching thread URL"

        assert html =~ ~s|target="_blank"|,
               "expected target=_blank on the source link"

        assert html =~ ~s|rel="noopener noreferrer"|,
               "expected rel=noopener noreferrer on the source link"

        {:ok, context}
      end
    end
  end
end
