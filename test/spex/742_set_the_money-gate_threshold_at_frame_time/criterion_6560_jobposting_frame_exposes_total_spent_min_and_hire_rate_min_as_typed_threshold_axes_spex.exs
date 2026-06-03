defmodule MarketMySpecSpex.Story742.Criterion6560Spex do
  @moduledoc """
  Story 742 — Set the money-gate threshold at Frame time
  Criterion 6560 — JobPosting Frame exposes total_spent_min and
  hire_rate_min as typed threshold axes.

  The Frame schema's money_gate field must carry two typed numeric
  threshold axes named total_spent_min and hire_rate_min — not a
  freeform map, not a single composite "threshold" value. The agent
  and the LiveView form both rely on these named axes.

  Interaction surface: Frame changeset validation — building a money_gate
  without those keys must fail.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.Frame

  spex "money_gate axes are total_spent_min + hire_rate_min, typed integers" do
    scenario "A money_gate map missing total_spent_min fails Frame changeset validation" do
      given_ "Frame attrs with a money_gate that has only hire_rate_min (missing total_spent_min)",
             context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          description: "Missing total_spent_min axis",
          saved_searches: ["upwork|anything"],
          money_gate: %{hire_rate_min: 50},
          min_money_gated_candidates: 1
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds a Frame changeset", context do
        changeset = Frame.changeset(%Frame{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid with an error on money_gate", context do
        refute context.changeset.valid?,
               "expected the changeset to be invalid (money_gate missing total_spent_min axis); got valid"

        assert :money_gate in Keyword.keys(context.changeset.errors),
               "expected a changeset error on :money_gate; got errors on: #{inspect(Keyword.keys(context.changeset.errors))}"
        {:ok, context}
      end
    end

    scenario "A money_gate with both typed integer axes passes validation" do
      given_ "Frame attrs with money_gate = total_spent_min:5000, hire_rate_min:50", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          description: "Typed money_gate axes",
          saved_searches: ["upwork|anything"],
          total_spent_min: 5000,
          hire_rate_min: 50,
          min_money_gated_candidates: 1
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds a Frame changeset", context do
        changeset = Frame.changeset(%Frame{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset has no errors on money_gate", context do
        money_gate_errors =
          Enum.filter(context.changeset.errors, fn {field, _} -> field == :money_gate end)

        assert money_gate_errors == [],
               "expected no errors on money_gate; got: #{inspect(money_gate_errors)}"
        {:ok, context}
      end
    end
  end
end
