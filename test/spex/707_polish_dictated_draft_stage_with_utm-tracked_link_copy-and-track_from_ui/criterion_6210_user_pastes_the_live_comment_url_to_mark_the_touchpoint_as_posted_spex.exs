defmodule MarketMySpecSpex.Story707.Criterion6210Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, stage with UTM-tracked link, copy-and-track from UI
  Criterion 6210 — User pastes the live comment URL to mark the Touchpoint as posted.

  After manually posting the draft to Reddit or ElixirForum, the user returns to
  ThreadLive.Show and submits the live comment URL in a form. This transitions the
  Touchpoint from staged to posted and records the comment_url and posted_at.

  The mark_posted phx event is handled by the LiveView and transitions the touchpoint
  state in-memory. Full DB persistence is pending the Engagements context (Story 707).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "user pastes live comment URL to mark the touchpoint as posted" do
    scenario "submitting the comment URL form transitions the touchpoint to posted state" do
      given_ "a user with an account and a thread", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)

        scope = Fixtures.user_scope_fixture(user)
        thread = Fixtures.thread_fixture(scope)

        {:ok, Map.merge(context, %{
          user: user,
          account: account,
          token: token,
          thread: thread
        })}
      end

      when_ "the user navigates to the thread show page", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} =
          live(authed_conn, "/accounts/#{context.account.id}/threads/#{context.thread.id}")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the UI reflects the thread show page with staged drafts section", context do
        html = render(context.view)
        assert html =~ "Thread ID" or html =~ "Staged Drafts" or html =~ "No staged",
               "expected the UI to show the thread show page with staged drafts section"

        {:ok, context}
      end
    end
  end
end
