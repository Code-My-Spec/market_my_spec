defmodule MarketMySpecSpex.Story742.Criterion6562Spex do
  @moduledoc """
  Story 742 — Set the money-gate threshold at Frame time
  Criterion 6562 — Score halts when the Frame has no money-gate threshold.

  If a Frame somehow exists without a money_gate (a corrupted record
  or a pre-validation state), invoking Score must halt with a clear
  error rather than silently classifying everything as gated_in or
  using a default.

  Interaction surface: Pipeline-level test — bypass changeset validation
  by directly inserting a Frame with nil money_gate, then call
  Pipeline.score/1 and observe the halt.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.Frame
  alias MarketMySpec.ProblemDiscovery.Pipeline

  spex "Score halts cleanly when Frame's money_gate is absent" do
    scenario "Calling Pipeline.score/1 with a Frame missing money_gate returns an error" do
      given_ "a Frame record with no money_gate (constructed in memory; not persisted via changeset)",
             context do
        frame = %Frame{
          id: Ecto.UUID.generate(),
          description: "Frame with no money_gate",
          saved_searches: [],
          money_gate: nil,
          kill_condition: %{min_money_gated_candidates: 1}
        }

        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the pipeline tries to Score against that Frame's id", context do
        result = Pipeline.score(context.frame.id)

        {:ok, Map.put(context, :result, result)}
      end

      then_ "Score returns an error (not :ok) — it does not produce PaidJobSignals from a missing gate",
            context do
        assert match?({:error, _}, context.result),
               "expected Score to return {:error, ...} for a Frame with no money_gate; got: #{inspect(context.result)}"
        {:ok, context}
      end
    end
  end
end
