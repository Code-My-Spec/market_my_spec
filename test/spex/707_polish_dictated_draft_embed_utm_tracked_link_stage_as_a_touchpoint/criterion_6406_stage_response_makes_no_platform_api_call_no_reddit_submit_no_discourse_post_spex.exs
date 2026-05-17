defmodule MarketMySpecSpex.Story707.Criterion6406Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6406 — `stage_response` makes no platform API call (no
  Reddit submit, no Discourse post); v1 only creates the Touchpoint
  row.

  Manual-paste model (per Reddit Responsible Builder Policy May 2026):
  MMS is NEVER a Reddit "app" — it never submits. The test installs a
  Req plug that records every outbound request and asserts the
  recorded list is empty after stage_response.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "stage_response makes zero outbound HTTP calls" do
    scenario "Install Req request recorder; stage_response runs; recorded request count == 0" do
      given_ "a persisted Reddit Thread and a Req request recorder installed", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "no406"})

        recorder = self()

        # Install a Req plug that captures any outbound request and
        # short-circuits with 599 (so any accidental HTTP attempt
        # surfaces as both a recorded request AND a noisy failure).
        plug = fn req ->
          send(recorder, {:outbound_req, req.url, req.method})

          %{req | response: Req.Response.new(status: 599, body: "FORBIDDEN_IN_TEST")}
        end

        Application.put_env(:market_my_spec, :reddit_req_options, plug: plug)
        Application.put_env(:market_my_spec, :elixirforum_req_options, plug: plug)

        on_exit_fn = fn ->
          Application.delete_env(:market_my_spec, :reddit_req_options)
          Application.delete_env(:market_my_spec, :elixirforum_req_options)
        end

        ExUnit.Callbacks.on_exit(on_exit_fn)

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls stage_response", context do
        {:reply, _stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Body https://x",
              link_target: "https://x"
            },
            context.frame
          )

        # Give the recorder a moment to drain any async send (defensive)
        Process.sleep(10)

        recorded =
          for {:outbound_req, url, method} <- collect_messages([]) do
            {method, url}
          end

        {:ok, Map.put(context, :recorded, recorded)}
      end

      then_ "zero outbound HTTP requests were issued during stage_response", context do
        assert context.recorded == [],
               "expected ZERO outbound HTTP calls during stage_response (manual-paste policy); got: #{inspect(context.recorded)}"

        {:ok, context}
      end
    end
  end

  defp collect_messages(acc) do
    receive do
      {:outbound_req, _, _} = msg -> collect_messages([msg | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
