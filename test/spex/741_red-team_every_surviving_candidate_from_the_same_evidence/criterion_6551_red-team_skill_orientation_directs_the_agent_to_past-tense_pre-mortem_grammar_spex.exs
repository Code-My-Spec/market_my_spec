defmodule MarketMySpecSpex.Story741.Criterion6551Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6551 — Red-team skill orientation directs the agent to past-tense
  pre-mortem grammar.

  The problem-discovery skill's Red-team step (step 05_redteam.md) must
  instruct the agent to use Klein's past-tense pre-mortem grammar — "this
  bet has already failed 18 months from now, what went wrong?" rather
  than the future-tense hedging form "what might go wrong?" The
  past-tense form activates specific recall and prevents balanced
  brainstorming.

  Interaction surface: file-backed module read (Skills.ProblemDiscovery
  reads step 05_redteam.md from priv/skills/problem-discovery/steps/).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Skills.ProblemDiscovery

  spex "Red-team step orientation directs the agent to past-tense pre-mortem grammar" do
    scenario "Reading step 05_redteam.md surfaces the past-tense framing" do
      given_ "the problem-discovery skill is on disk under priv/skills/problem-discovery/",
             context do
        {:ok, context}
      end

      when_ "the agent reads the Red-team step file", context do
        assert {:ok, body} = ProblemDiscovery.read_skill_file("steps/05_redteam.md")

        {:ok, Map.put(context, :body, body)}
      end

      then_ "the step body uses past-tense pre-mortem grammar (Klein)", context do
        assert context.body =~ ~r/past[- ]tense/i,
               "expected the Red-team step to explicitly name past-tense (Klein pre-mortem) grammar"

        assert context.body =~ ~r/Klein/,
               "expected the Red-team step to cite Klein (the source of the pre-mortem framing)"

        assert context.body =~ ~r/(has |have )already failed|18 months from now|prosp.*hindsight/i,
               "expected the Red-team step to model the past-tense form ('has already failed', 'looking back', 'prospective hindsight')"
        {:ok, context}
      end

      then_ "the step body explicitly NOT-frames the future-tense hedging form", context do
        assert context.body =~ ~r/not.*what could go wrong|adversarial|prosecut/i,
               "expected the Red-team step to set the adversarial framing apart from 'what could go wrong' balanced brainstorming"
        {:ok, context}
      end
    end
  end
end
