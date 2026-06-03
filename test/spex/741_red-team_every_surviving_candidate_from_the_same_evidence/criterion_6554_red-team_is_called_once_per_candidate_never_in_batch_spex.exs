defmodule MarketMySpecSpex.Story741.Criterion6554Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6554 — Red-team is called once per Candidate, never in batch.

  The RedTeamCandidate MCP tool's schema is structured per-Candidate
  (single `candidate_id` parameter). There must NOT be a batch
  RedTeamCandidates variant that prosecutes many in one call —
  prosecution is conversational and the founder is in the loop on top
  candidates (per the Three Amigos resolution on 742).

  Interaction surface: introspection of the RedTeamCandidate tool's
  declared schema and module surface.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RedTeamCandidate

  spex "RedTeamCandidate is single-Candidate by contract; no batch variant exists" do
    scenario "The RedTeamCandidate tool's schema expects exactly one candidate_id (not a list)" do
      given_ "the RedTeamCandidate module is loadable", context do
        Code.ensure_loaded!(RedTeamCandidate)
        {:ok, context}
      end

      when_ "introspecting the tool's input schema and module functions", context do
        {:ok, context}
      end

      then_ "the schema declares candidate_id as a single string, not a list of ids",
            context do
        # Anubis components define their schema via the `schema do` macro.
        # The compiled schema can be introspected via the module's
        # callbacks. We assert that the schema's input_schema/0 names
        # `candidate_id` as a single string field — not `candidate_ids`
        # nor a list.
        input_schema_callback? =
          function_exported?(RedTeamCandidate, :input_schema, 0) or
            function_exported?(RedTeamCandidate, :__schema__, 1) or
            function_exported?(RedTeamCandidate, :anubis_input_schema, 0)

        assert input_schema_callback?,
               "expected RedTeamCandidate to expose an introspectable input schema"

        # Source-level structural check: the schema block must NOT
        # declare a candidate_ids (plural list) field — that would
        # contradict the per-Candidate prosecution rule.
        source = File.read!("lib/market_my_spec/mcp_servers/problem_discovery/tools/red_team_candidate.ex")

        refute source =~ ~r/field\s+:candidate_ids/,
               "expected the RedTeamCandidate tool to not declare a :candidate_ids (plural/list) field; prosecution is per-Candidate"

        assert source =~ ~r/field\s+:candidate_id\s*,\s*:string/,
               "expected the RedTeamCandidate tool to declare a single :candidate_id string field"
        {:ok, context}
      end

      then_ "no sibling RedTeamCandidates (plural) batch tool exists in the registered MCP server tree",
            context do
        refute Code.ensure_loaded?(MarketMySpec.McpServers.ProblemDiscovery.Tools.RedTeamCandidates),
               "expected NO batch RedTeamCandidates tool to be present; prosecution is one-at-a-time"
        {:ok, context}
      end
    end
  end
end
