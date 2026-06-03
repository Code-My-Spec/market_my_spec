defmodule MarketMySpecSpex.Story741.Criterion6548Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6548 — RedTeamVerdict carries exactly one kill_argument string.

  The RedTeamVerdict schema enforces that kill_argument is a single
  required string (one prosecution per verdict — devil's-advocate
  single-thread, not a balanced multi-point report). Persistence of a
  verdict without a kill_argument or with a non-string kill_argument
  must be rejected.

  Interaction surface: changeset-level validation on the RedTeamVerdict
  schema.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.RedTeamVerdict

  spex "RedTeamVerdict carries exactly one kill_argument string and rejects absence" do
    scenario "Building a RedTeamVerdict changeset without a kill_argument fails validation" do
      given_ "a RedTeamVerdict attribute map missing kill_argument", context do
        attrs = %{
          candidate_id: Ecto.UUID.generate(),
          verdict: :kill,
          cheapest_kill_test: "one phone call"
          # kill_argument intentionally omitted
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds the changeset", context do
        changeset = RedTeamVerdict.changeset(%RedTeamVerdict{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid with a missing-kill_argument error", context do
        refute context.changeset.valid?,
               "expected the changeset to be invalid (missing kill_argument); got valid"

        assert :kill_argument in Keyword.keys(context.changeset.errors),
               "expected a changeset error on :kill_argument; got: #{inspect(Keyword.keys(context.changeset.errors))}"
        {:ok, context}
      end
    end

    scenario "A valid RedTeamVerdict carries kill_argument as a single string field" do
      given_ "a full RedTeamVerdict attribute map with a single kill_argument string", context do
        attrs = %{
          candidate_id: Ecto.UUID.generate(),
          verdict: :kill,
          kill_argument: "18 months from now this failed because the top 3 spenders all hired in Q1 2024 and never returned.",
          cheapest_kill_test: "Phone calls with those 3 clients to check whether they re-posted."
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds the changeset", context do
        changeset = RedTeamVerdict.changeset(%RedTeamVerdict{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid and the kill_argument round-trips as a single string",
            context do
        assert context.changeset.valid?,
               "expected the changeset to be valid; errors: #{inspect(context.changeset.errors)}"

        assert Ecto.Changeset.get_field(context.changeset, :kill_argument) ==
                 context.attrs.kill_argument,
               "expected kill_argument to round-trip as a single string"

        assert is_binary(Ecto.Changeset.get_field(context.changeset, :kill_argument)),
               "expected kill_argument to be a binary string"
        {:ok, context}
      end
    end
  end
end
