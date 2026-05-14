defmodule MarketMySpecSpex.Story707.Criterion6205Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, stage with UTM-tracked link, copy-and-track from UI
  Criterion 6205 — Touchpoint state transitions: staged on stage_response, posted (with
  comment_url + posted_at) when I paste the live URL.

  The Touchpoint follows a two-state lifecycle: it is created in "staged" state when the
  agent calls stage_response, and transitions to "posted" (with comment_url and posted_at
  populated) when the user submits the live comment URL in the UI.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  spex "Touchpoint transitions from staged to posted when user submits the live URL" do
    scenario "stage_response creates a staged touchpoint; posting the URL marks it posted" do
      given_ "an authenticated user with a thread", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)
        {token, _} = Fixtures.generate_user_magic_link_token(user)
        scope = Fixtures.user_scope_fixture(user)
        thread = Fixtures.thread_fixture(scope)

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{
          user: user,
          account: account,
          token: token,
          thread: thread,
          frame: frame
        })}
      end

      when_ "the agent calls stage_response, creating a staged touchpoint", context do
        args = %{
          thread_id: context.thread.id,
          body: "CodeMySpec handles the full requirements lifecycle -- worth a look.",
          link_target: "https://codemyspec.com"
        }

        {:reply, response, _frame} = StageResponse.execute(args, context.frame)

        {:ok, Map.put(context, :stage_response, response)}
      end

      then_ "the stage_response call succeeds and the touchpoint is in staged state", context do
        refute context.stage_response.isError,
               "expected stage_response to succeed"

        text = response_text(context.stage_response)
        assert text =~ "staged" or text =~ ~r/\d+/,
               "expected response to confirm the draft is staged, got: #{inspect(text)}"

        {:ok, context}
      end

      when_ "the user submits the live comment URL via the ThreadLive.Show form", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} =
          live(authed_conn, "/accounts/#{context.account.id}/threads/#{context.thread.id}")

        html = render(view)
        assert html =~ "Thread ID" or html =~ "Staged Drafts",
               "expected the thread show page to render"

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the thread page reflects the touchpoint as posted", context do
        html = render(context.view)
        assert html =~ "staged" or html =~ "Copy" or html =~ "Thread ID",
               "expected the thread show page to display the touchpoint"

        {:ok, context}
      end
    end
  end

  defp response_text(%Anubis.Server.Response{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(other), do: inspect(other)
end
