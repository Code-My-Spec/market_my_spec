defmodule MarketMySpecSpex.Story706.Criterion6382Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6382 — Account B's call for Account A's Thread returns
  :not_found and triggers no HTTP.

  Sister to 6373; pinned via Three Amigos scenario. Empty cassette
  (zero interactions) — if the impl made any HTTP call, ReqCassette in
  :replay would raise. Response is an error / :not_found; no Thread
  data leaks; A's row is unchanged.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  spex "Cross-account: Account B's call returns :not_found, makes no HTTP" do
    scenario "Account A owns Thread T-a; Account B calls get_thread(T-a.id); empty cassette" do
      given_ "Account A owns T-a; Account B signed in; cassette has zero interactions",
             context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        thread_a =
          Fixtures.thread_fixture(scope_a, %{
            source: :reddit,
            source_thread_id: "iso_6382",
            op_body: "A's private content — must not leak"
          })

        path = "test/cassettes/reddit/crit_6382_isolation.json"
        File.mkdir_p!("test/cassettes/reddit")
        File.write!(path, Jason.encode!(%{"version" => "1.0", "interactions" => []}))
        ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)

        {:ok, Map.merge(context, %{frame_b: build_frame(scope_b), thread_a: thread_a})}
      end

      when_ "Account B's frame calls get_thread on A's UUID", context do
        result =
          RedditHelpers.with_reddit_cassette("crit_6382_isolation", fn ->
            GetThread.execute(%{thread_id: context.thread_a.id}, context.frame_b)
          end)

        {:ok, Map.put(context, :result, result)}
      end

      then_ "response is error (not_found); no HTTP was attempted; no leak", context do
        case context.result do
          {:reply, %Response{isError: true} = response, _frame} ->
            text = response.content |> Enum.map_join("", fn
              %{"text" => t} -> t
              %{text: t} -> t
              other -> inspect(other)
            end)
            refute text =~ "A's private content",
                   "expected no leak of A's op_body, got: #{text}"

          {:error, :not_found} ->
            :ok

          other ->
            flunk("expected error response, got: #{inspect(other)}")
        end

        {:ok, context}
      end
    end
  end
end
