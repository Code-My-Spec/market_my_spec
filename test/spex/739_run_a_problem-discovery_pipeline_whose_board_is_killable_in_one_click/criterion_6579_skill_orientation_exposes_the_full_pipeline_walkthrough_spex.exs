defmodule MarketMySpecSpex.Story739.Criterion6579Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6579 — Skill orientation exposes the full pipeline walkthrough.

  The problem-discovery skill's orientation document (SKILL.md, served via
  Skills.ProblemDiscovery.read_skill_md/0) enumerates all six pipeline
  phases (Frame, Gather, Cluster, Score, Red-team, Board), names the
  ProblemDiscovery MCP tools the agent invokes per phase, and distinguishes
  founder-direct LiveView surfaces from skill-driven agent flows.

  Interaction surface: file-backed module read (Skills.ProblemDiscovery.read_skill_md/0).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Skills.ProblemDiscovery

  @phase_names ~w(Frame Gather Cluster Score Red-team Board)

  @required_tools ~w(
    CreateFrame
    RunGather
    RunCluster
    RunScore
    RedTeamCandidate
    GetBoard
    SetPainDescriptor
    MergeCandidates
    SplitCandidate
    LabelCandidate
  )

  spex "Skill orientation enumerates the 6 phases, names per-phase tools, and maps surfaces" do
    scenario "Skills.ProblemDiscovery.read_skill_md/0 returns an orientation covering phases, tools, and surface map" do
      given_ "the problem-discovery skill is on disk under priv/skills/problem-discovery/",
             context do
        # The skill module reads from priv/; no external setup needed.
        {:ok, context}
      end

      when_ "the agent reads the skill orientation", context do
        assert {:ok, body} = ProblemDiscovery.read_skill_md()

        {:ok, Map.put(context, :body, body)}
      end

      then_ "the orientation enumerates all six pipeline phases", context do
        for phase <- @phase_names do
          assert context.body =~ phase,
                 "expected orientation to enumerate phase #{phase}; not present in SKILL.md body"
        end

        {:ok, context}
      end

      then_ "the orientation names every ProblemDiscovery MCP tool the agent invokes during the walkthrough",
            context do
        for tool <- @required_tools do
          assert context.body =~ tool,
                 "expected orientation to name MCP tool #{tool}; not present in SKILL.md body"
        end

        {:ok, context}
      end

      then_ "the orientation distinguishes founder-direct LiveView surfaces from skill-driven agent flows",
            context do
        assert context.body =~ ~r/founder[- ]direct/i or context.body =~ ~r/LiveView/,
               "expected orientation to mention founder-direct or LiveView surfaces"

        assert context.body =~ ~r/skill[- ]driven/i or context.body =~ ~r/agent flow/i,
               "expected orientation to mention skill-driven or agent flows"

        {:ok, context}
      end
    end
  end
end
