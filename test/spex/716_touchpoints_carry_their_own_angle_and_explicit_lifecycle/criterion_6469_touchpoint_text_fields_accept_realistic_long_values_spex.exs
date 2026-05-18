defmodule MarketMySpecSpex.Story716.Criterion6469Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6469 (pending CMS filing) — Touchpoint storage columns
  (polished_body, angle, link_target, comment_url) and Thread.synopsis
  accept realistic-length values without varchar(255) truncation.

  Regression guard for the 22001 string_data_right_truncation crash that
  shipped on 2026-05-17: angle was declared :string (varchar 255) but real
  agent calls send 400+ char reasoning paragraphs; the schema was widened
  to :text in migration 20260517210000_widen_touchpoint_text_fields.

  Exercises stage_response + update_touchpoint with realistic content sizes
  and asserts every value round-trips intact via Engagements reads.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpec.McpServers.Engagements.Tools.UpdateTouchpoint
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

  # 600+ char angle: a real agent reasoning paragraph
  defp long_angle do
    "Pivot from chat-context hygiene to the structured/durable context layer. " <>
      "Don't fight OP's catalog — pick up mm_cm_m_km's surfaced gap (CLAUDE.md " <>
      "drift, rules silently contradicting) and reframe: chat is disposable, " <>
      "structure is durable, the real leverage is keeping module specs / scenarios " <>
      "/ rules coherent as they grow. Anchor on the BDD-specs-for-AI thread and " <>
      "the existing reference architecture; avoid mentioning monetization or product " <>
      "names beyond the single inline link. Tone: practical, voice-of-someone-who's-" <>
      "shipped, no hype. Avoid em-dashes (Reddit spam filter)."
  end

  # 1200+ char polished_body: a multi-paragraph Reddit comment
  defp long_body do
    """
    These four manage chat context. The thing they don't touch is the structured
    layer — CLAUDE.md, plan files, slash command bodies, sub-agent prompts —
    which rots on a different schedule and is usually the real source of
    "Claude got dumber after lunch."

    mm_cm_m_km nailed it above: 400 lines of CLAUDE.md, half contradicting each
    other, and no `/compact` resolves it because the contradiction isn't in the
    conversation. It's baked into the files the model loads every turn before it
    even sees your prompt.

    The framing that works for me: chat is disposable, structure is durable,
    push state into the durable layer. Then `/clear` between phases is free
    (landed-gentry is right), and `/btw` is the only side-question tool you need.

    The hard part is keeping the durable layer coherent as it grows — module
    specs that match the code, scenarios that match the specs, rules that don't
    quietly disagree. Wrote up the shape of that pipeline here:
    https://codemyspec.com/blog/bdd-specs-for-ai-generated-code
    """
  end

  # ~400 char synopsis
  defp long_synopsis do
    "Catalog post highlighting four lesser-known Claude Code context tools " <>
      "(/btw, /compact-with-instructions, /summarize-up-to-here, /clear) as the " <>
      "middle ground between /clear and /compact. Room is split: top comment loves " <>
      "/btw, a strong dissent argues /clear should be first-resort if you keep a " <>
      "plan.md, and one commenter (mm_cm_m_km) surfaces the unscanned gap — the " <>
      "static layer (CLAUDE.md, rules, slash-command bodies) rots independently " <>
      "and none of these chat-side commands touch it."
  end

  # 300+ char Reddit comment URL with full post slug + comment id + tracking query
  # (deliberately exceeds varchar(255) to prove the widening exercised)
  defp long_comment_url do
    "https://www.reddit.com/r/ClaudeAI/comments/1nu46o2/" <>
      "anthropic_shipped_four_lesser_known_context_tools_between_clear_and_compact_heres_when_each_one_wins_a_detailed_practical_breakdown_for_solo_founders_and_indie_devs/" <>
      "kx2abcde9f/?context=3&utm_source=share&utm_medium=web&utm_campaign=mms_followup"
  end

  spex "long polished_body / angle / synopsis / comment_url survive without truncation" do
    scenario "stage_response with realistic payload, then update_touchpoint with long angle + body, then mark_posted with long URL — all values round-trip" do
      given_ "an empty thread + scope", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "long6469"})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages a realistic-length response, then revises, then marks posted with a long URL",
            context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: long_body(),
              link_target: "https://codemyspec.com/blog/bdd-specs-for-ai-generated-code",
              angle: long_angle(),
              synopsis: long_synopsis()
            },
            context.frame
          )

        touchpoint_id = (decode_payload(stage_resp))["touchpoint_id"]
        refute is_nil(touchpoint_id), "expected touchpoint_id in stage_response payload"

        revised_angle = long_angle() <> " (revised after the OP replied)"

        {:reply, _update_resp, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: touchpoint_id,
              polished_body: long_body() <> "\n\nEdit: clarified the static-vs-chat split.",
              angle: revised_angle
            },
            context.frame
          )

        posted_at_iso = "2026-05-17T20:55:00Z"

        {:reply, _post_resp, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: touchpoint_id,
              state: "posted",
              comment_url: long_comment_url(),
              posted_at: posted_at_iso
            },
            context.frame
          )

        {:ok, reloaded_touchpoint} =
          Engagements.get_touchpoint_by_id(context.scope, touchpoint_id)

        {:ok, reloaded_thread} =
          Engagements.get_thread_by_id(context.scope, context.thread.id)

        {:ok,
         Map.merge(context, %{
           touchpoint: reloaded_touchpoint,
           thread_after: reloaded_thread,
           revised_angle: revised_angle
         })}
      end

      then_ "every long value persisted in full — no truncation, no crash", context do
        tp = context.touchpoint
        th = context.thread_after

        assert String.starts_with?(tp.polished_body, "These four manage chat context"),
               "expected revised polished_body persisted"

        assert String.ends_with?(tp.polished_body, "clarified the static-vs-chat split."),
               "expected the edited tail of polished_body persisted, got tail: " <>
                 inspect(String.slice(tp.polished_body, -60, 60))

        assert tp.angle == context.revised_angle,
               "expected long revised angle persisted in full (got #{byte_size(tp.angle || "")} bytes vs expected #{byte_size(context.revised_angle)})"

        assert byte_size(tp.angle) > 600,
               "expected angle > 600 bytes to actually exercise the widening; got #{byte_size(tp.angle)}"

        assert tp.comment_url == long_comment_url(),
               "expected long comment_url persisted in full (got #{byte_size(tp.comment_url || "")} bytes vs expected #{byte_size(long_comment_url())})"

        assert byte_size(tp.comment_url) > 255,
               "expected comment_url > 255 bytes to actually exercise the widening; got #{byte_size(tp.comment_url)}"

        assert tp.state == :posted, "expected state :posted after mark-posted call"

        assert th.synopsis == long_synopsis(),
               "expected long synopsis persisted on thread in full"

        {:ok, context}
      end
    end
  end
end
