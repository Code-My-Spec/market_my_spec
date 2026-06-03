defmodule MarketMySpecSpex.Story741.Criterion6549Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6549 — RedTeamVerdict carries exactly one cheapest_kill_test string.

  The RedTeamVerdict schema enforces that cheapest_kill_test is a
  single required string (one concrete next experiment that would
  confirm or kill the verdict). Persistence without it or with the
  wrong shape must be rejected.

  Interaction surface: changeset-level validation on the RedTeamVerdict
  schema.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.RedTeamVerdict

  spex "RedTeamVerdict requires exactly one cheapest_kill_test string" do
    scenario "Building a RedTeamVerdict changeset without a cheapest_kill_test fails validation" do
      given_ "a RedTeamVerdict attribute map missing cheapest_kill_test", context do
        attrs = %{
          candidate_id: Ecto.UUID.generate(),
          verdict: :keep_productizable,
          kill_argument: "Demand looks broad but is concentrated in 2 clients."
          # cheapest_kill_test intentionally omitted
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds the changeset", context do
        changeset = RedTeamVerdict.changeset(%RedTeamVerdict{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid with a missing-cheapest_kill_test error", context do
        refute context.changeset.valid?,
               "expected the changeset to be invalid (missing cheapest_kill_test); got valid"

        assert :cheapest_kill_test in Keyword.keys(context.changeset.errors),
               "expected a changeset error on :cheapest_kill_test; got: #{inspect(Keyword.keys(context.changeset.errors))}"
        {:ok, context}
      end
    end

    scenario "A valid RedTeamVerdict carries cheapest_kill_test as a single string field" do
      given_ "a full RedTeamVerdict attribute map with a cheapest_kill_test string", context do
        attrs = %{
          candidate_id: Ecto.UUID.generate(),
          verdict: :keep_productizable,
          kill_argument: "Strong demand but services-tier may not translate to product.",
          cheapest_kill_test: "Pre-sell a $99/mo waitlist to 5 of these clients; cancel if zero credit cards."
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds the changeset", context do
        changeset = RedTeamVerdict.changeset(%RedTeamVerdict{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "cheapest_kill_test round-trips as a single string", context do
        assert context.changeset.valid?,
               "expected the changeset to be valid; errors: #{inspect(context.changeset.errors)}"

        assert Ecto.Changeset.get_field(context.changeset, :cheapest_kill_test) ==
                 context.attrs.cheapest_kill_test

        assert is_binary(Ecto.Changeset.get_field(context.changeset, :cheapest_kill_test))
        {:ok, context}
      end
    end
  end
end
