defmodule MarketMySpecSpex.Story742.Criterion6563Spex do
  @moduledoc """
  Story 742 — Set the money-gate threshold at Frame time
  Criterion 6563 — Frame commit is rejected without a kill_condition.

  Attempting to create a Frame without a kill_condition must fail at
  changeset validation. The pre-commitment is non-negotiable per
  Blank/Fitzpatrick — a hypothesis without a kill condition is not a
  hypothesis, it's a wishlist.

  Interaction surface: Frame changeset validation.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.Frame

  spex "Frame commit is rejected when kill_condition is absent" do
    scenario "Building a Frame changeset without kill_condition fails validation" do
      given_ "Frame attrs with no kill_condition key at all", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          description: "Frame missing kill_condition",
          saved_searches: [%{source: "upwork", query: "anything"}],
          money_gate: %{total_spent_min: 5000, hire_rate_min: 50}
          # kill_condition intentionally omitted
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds the changeset", context do
        changeset = Frame.changeset(%Frame{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid with a kill_condition error", context do
        refute context.changeset.valid?,
               "expected the changeset to be invalid (kill_condition required); got valid"

        assert :kill_condition in Keyword.keys(context.changeset.errors),
               "expected a changeset error on :kill_condition; got errors on: #{inspect(Keyword.keys(context.changeset.errors))}"
        {:ok, context}
      end
    end
  end
end
