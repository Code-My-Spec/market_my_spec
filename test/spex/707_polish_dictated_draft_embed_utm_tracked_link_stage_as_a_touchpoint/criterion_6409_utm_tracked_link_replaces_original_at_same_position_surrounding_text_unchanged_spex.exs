defmodule MarketMySpecSpex.Story707.Criterion6409Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6409 — UTM-tracked link replaces the original link_target
  at the same position; surrounding text unchanged.

  Sister to 6402; pinned via Three Amigos scenario. Uses a body with
  multi-paragraph structure to make position-preservation observable.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
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

  spex "UTM-tracked link replaces link_target at same position; surrounding text preserved" do
    scenario "Multi-paragraph body, link buried mid-body; substitution is position-preserving" do
      given_ "a Reddit Thread (sub: elixir)", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "pos409",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages a body with paragraph-before, inline link, paragraph-after", context do
        link_target = "https://marketmyspec.com/breakdown"

        paragraph_before =
          "Quick thought on this — the harness layer is doing more work than the model is. "

        inline_text = "Wrote this up here: "
        paragraph_after = "\n\nWould love feedback on the diagram on page 2."

        polished_body = paragraph_before <> inline_text <> link_target <> paragraph_after

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: polished_body,
              link_target: link_target
            },
            context.frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        touchpoints =
          (decode_payload(list_resp))["touchpoints"] ||
            (decode_payload(list_resp))["list"] || []

        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == touchpoint_id))

        {:ok,
         Map.merge(context, %{
           stored_body: tp && (tp["polished_body"] || tp[:polished_body]),
           paragraph_before: paragraph_before,
           inline_text: inline_text,
           paragraph_after: paragraph_after,
           original_link: link_target
         })}
      end

      then_ "stored body == before <> inline <> UTM-link <> after; surrounding text byte-for-byte preserved",
            context do
        assert context.stored_body, "expected stored polished_body"

        assert String.starts_with?(context.stored_body, context.paragraph_before),
               "expected paragraph-before preserved verbatim"

        assert String.ends_with?(context.stored_body, context.paragraph_after),
               "expected paragraph-after preserved verbatim"

        assert context.stored_body =~ context.inline_text,
               "expected inline framing text preserved verbatim"

        # Extract what's between paragraph_before+inline and paragraph_after
        prefix = context.paragraph_before <> context.inline_text
        without_prefix = String.replace_prefix(context.stored_body, prefix, "")
        link_substr = String.replace_suffix(without_prefix, context.paragraph_after, "")

        assert link_substr =~ context.original_link,
               "expected base URL still present at link_target position; got: #{link_substr}"

        assert link_substr =~ "utm_source=reddit",
               "expected UTM-tracked URL at link_target position; got: #{link_substr}"

        {:ok, context}
      end
    end
  end
end
