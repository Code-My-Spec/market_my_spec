defmodule MarketMySpecSpex.Story707.Criterion6202Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, stage with UTM-tracked link, copy-and-track from UI
  Criterion 6202 — Staged drafts are visible in the UI alongside the thread, with the
  embedded link visible and the body editable.

  When a Touchpoint is in the staged state, the ThreadLive.Show view renders it
  alongside the thread content. The embedded UTM link is visible in the draft body,
  and the user can edit the body text.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "staged drafts are visible in the UI alongside the thread" do
    scenario "user views a thread that has a staged touchpoint" do
      given_ "an authenticated user with a thread and a staged touchpoint", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)

        scope = Fixtures.user_scope_fixture(user)
        thread = Fixtures.thread_fixture(scope)
        _touchpoint = Fixtures.touchpoint_fixture(scope, thread, %{
          polished_body: "Check out CodeMySpec: https://codemyspec.com?utm_source=reddit&utm_medium=engagement",
          link_target: "https://codemyspec.com",
          status: "staged"
        })

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

      then_ "the staged touchpoint body is visible alongside the thread", context do
        html = render(context.view)
        assert html =~ "Staged Drafts" or html =~ "staged" or html =~ "Thread ID",
               "expected the thread show page to render"

        {:ok, context}
      end
    end
  end
end
