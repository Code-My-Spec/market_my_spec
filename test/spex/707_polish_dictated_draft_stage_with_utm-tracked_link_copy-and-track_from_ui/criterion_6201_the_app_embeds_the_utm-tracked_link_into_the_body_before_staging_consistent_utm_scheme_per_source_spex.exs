defmodule MarketMySpecSpex.Story707.Criterion6201Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, stage with UTM-tracked link, copy-and-track from UI
  Criterion 6201 — The app embeds the UTM-tracked link into the body before staging
  (consistent UTM scheme per source).

  When stage_response is called with a link_target, the app embeds the UTM-tracked
  link into the body using the per-source UTM scheme before saving the Touchpoint.
  For Reddit: utm_source=reddit, utm_medium=engagement, utm_campaign={subreddit},
  utm_content={thread_id}.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  spex "app embeds the UTM-tracked link into the body before staging" do
    scenario "agent stages a response for a Reddit thread and the body gets UTM link embedded" do
      given_ "an authenticated user with a Reddit thread in their account", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        thread = Fixtures.thread_fixture(scope, %{source: "reddit"})

        {:ok, Map.merge(context, %{scope: scope, frame: frame, thread: thread})}
      end

      when_ "the agent calls stage_response with a bare link_target", context do
        args = %{
          thread_id: context.thread.id,
          body: "This is a great question -- check out CodeMySpec for requirements-driven dev.",
          link_target: "https://codemyspec.com"
        }

        {:reply, response, _frame} = StageResponse.execute(args, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the staged touchpoint body contains UTM parameters for the reddit source", context do
        refute context.response.isError, "expected stage_response to succeed"
        text = response_text(context.response)

        assert text =~ "utm_source=reddit",
               "expected staged body to contain utm_source=reddit, got: #{inspect(text)}"

        assert text =~ "utm_medium=engagement",
               "expected staged body to contain utm_medium=engagement, got: #{inspect(text)}"

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
