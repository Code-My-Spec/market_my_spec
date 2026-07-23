defmodule MarketMySpecSpex.Story706.Criterion6373Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6373 — Cross-account access (UUID owned by a different
  account) returns :not_found and leaks no thread data.

  Account A owns Thread T-a. Dave on Account B calls get_thread(T-a.id).
  Cassette is empty (no HTTP call expected). Response is
  {:error, :not_found}; no Thread data leaked; no exception.

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

  spex "Cross-account get_thread returns :not_found; no HTTP, no leak" do
    scenario "Account B's frame requests Account A's Thread" do
      given_ "Account A owns Thread T-a; Account B signed in; cassette has zero interactions",
             context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        thread_a =
          Fixtures.thread_fixture(scope_a, %{
            source: :reddit,
            source_thread_id: "secret_thread_a",
            op_body: "Account A's private content"
          })

        # Empty cassette — any HTTP call in :replay mode would raise
        cassette_path = "test/cassettes/reddit/crit_6373_isolation.json"
        File.mkdir_p!("test/cassettes/reddit")
        File.write!(cassette_path, Jason.encode!(%{"version" => "1.0", "interactions" => []}))
        ExUnit.Callbacks.on_exit(fn -> File.rm(cassette_path) end)

        {:ok,
         Map.merge(context, %{
           frame_b: build_frame(scope_b),
           thread_a: thread_a
         })}
      end

      when_ "Dave's frame (Account B) calls get_thread with Account A's UUID", context do
        result =
          RedditHelpers.with_reddit_cassette("crit_6373_isolation", fn ->
            GetThread.execute(%{thread_id: context.thread_a.id}, context.frame_b)
          end)

        {:ok, Map.put(context, :result, result)}
      end

      then_ "response is an error (not_found); no Thread data leaks", context do
        # Response can be {:reply, %Response{isError: true}, frame} or {:error, :not_found}
        case context.result do
          {:reply, %Response{isError: true} = response, _frame} ->
            # Check the error text doesn't leak A's data
            text = response.content |> Enum.map_join("", fn
              %{"text" => t} -> t
              %{text: t} -> t
              other -> inspect(other)
            end)
            refute text =~ "Account A's private content",
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
