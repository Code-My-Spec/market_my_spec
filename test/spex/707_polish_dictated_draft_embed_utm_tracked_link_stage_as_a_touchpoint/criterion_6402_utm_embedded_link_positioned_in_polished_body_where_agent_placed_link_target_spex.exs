defmodule MarketMySpecSpex.Story707.Criterion6402Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6402 — The UTM-embedded link is positioned in
  `polished_body` where the agent placed the original `link_target`
  substring; the result is stored as the Touchpoint's `polished_body`.

  Position-preserving substitution: the original link_target appears
  in the middle of a longer body; after stage_response the surrounding
  prose is byte-for-byte identical and only the link_target substring
  is replaced with the UTM-tracked URL.

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

  spex "UTM-embedded link replaces link_target at the same position" do
    scenario "Body has prose-before, link_target, prose-after; UTM URL slots in at the link_target spot" do
      given_ "a Reddit Thread (subreddit: elixir)", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "pos402",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages a body with prose-before LINK prose-after structure", context do
        link_target = "https://marketmyspec.com/landing"
        prose_before = "Hey, I wrote up the breakdown here: "
        prose_after = " — would love your take on the harness layer."
        polished_body = prose_before <> link_target <> prose_after

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
        stored_body = tp && (tp["polished_body"] || tp[:polished_body])

        {:ok,
         Map.merge(context, %{
           original_link: link_target,
           prose_before: prose_before,
           prose_after: prose_after,
           stored_body: stored_body
         })}
      end

      then_ "surrounding prose unchanged byte-for-byte; only link_target replaced with UTM URL",
            context do
        assert context.stored_body, "expected stored polished_body on touchpoint"

        assert String.starts_with?(context.stored_body, context.prose_before),
               "expected prose-before unchanged; got: #{context.stored_body}"

        assert String.ends_with?(context.stored_body, context.prose_after),
               "expected prose-after unchanged; got: #{context.stored_body}"

        # The original (un-UTM'd) link_target should no longer appear verbatim
        # in the body. The UTM-embedded URL should appear in its place.
        utm_substr = String.replace(context.stored_body, context.prose_before, "")
        utm_substr = String.replace(utm_substr, context.prose_after, "")

        assert utm_substr =~ context.original_link,
               "expected base URL still in URL; got UTM substr: #{utm_substr}"

        assert utm_substr =~ "utm_source=reddit",
               "expected UTM-embedded link at the link_target position; got: #{utm_substr}"

        assert context.stored_body =~
                 (context.original_link <> "?utm_source=reddit"),
               "expected exactly one UTM-embedded link (?utm_source=reddit suffix) at the link_target position"

        # Body should have exactly one occurrence of the base URL — no double-link, no append
        occurrences =
          context.stored_body
          |> String.split(context.original_link)
          |> length()
          |> Kernel.-(1)

        assert occurrences == 1,
               "expected exactly 1 occurrence of base URL, got #{occurrences}; body: #{context.stored_body}"

        {:ok, context}
      end
    end
  end
end
