defmodule MarketMySpecSpex.Story742.Criterion6561Spex do
  @moduledoc """
  Story 742 — Set the money-gate threshold at Frame time
  Criterion 6561 — kill_condition is stored as structured data, not prose.

  The Frame schema's kill_condition field must be a structured map with
  named typed keys (min_money_gated_candidates), not a freeform string.
  This lets downstream code (Board, kill_condition_status) reliably
  parse and apply the founder's pre-commitment.

  Interaction surface: Frame changeset validation — a kill_condition
  that's a string instead of a map must fail.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.Frame

  spex "kill_condition must be structured data with min_money_gated_candidates key, not prose" do
    scenario "Building a Frame with kill_condition as a string fails validation" do
      given_ "Frame attrs with kill_condition = \"fewer than 3 money-gated candidates\" (prose)",
             context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          description: "Prose kill_condition",
          saved_searches: ["upwork|anything"],
          total_spent_min: 5000,
          hire_rate_min: 50,
          kill_condition: "fewer than 3 money-gated candidates"
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds a Frame changeset", context do
        changeset = Frame.changeset(%Frame{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid with an error on kill_condition (prose is not accepted)",
            context do
        refute context.changeset.valid?,
               "expected the changeset to reject prose kill_condition; got valid"
        {:ok, context}
      end
    end

    scenario "A kill_condition map with min_money_gated_candidates is accepted" do
      given_ "Frame attrs with kill_condition = %{min_money_gated_candidates: 3}", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          description: "Structured kill_condition",
          saved_searches: ["upwork|anything"],
          total_spent_min: 5000,
          hire_rate_min: 50,
          min_money_gated_candidates: 3
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds a Frame changeset", context do
        changeset = Frame.changeset(%Frame{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "no error appears on kill_condition", context do
        kc_errors =
          Enum.filter(context.changeset.errors, fn {field, _} -> field == :kill_condition end)

        assert kc_errors == [],
               "expected no errors on kill_condition; got: #{inspect(kc_errors)}"
        {:ok, context}
      end
    end
  end
end
