defmodule MarketMySpecSpex.Story740.Criterion6541Spex do
  @moduledoc """
  Story 740 — Pluggable data sources behind a fixed validation contract
  Criterion 6541 — UpworkAdapter implements the Source behaviour.

  Source.Upwork must declare @behaviour MarketMySpec.ProblemDiscovery.Source
  and implement every callback the behaviour defines. This is the
  structural test for the pluggability contract: any new adapter going
  forward will be expected to satisfy the same shape.

  Interaction surface: introspection of the Upwork module's exported
  behaviours and callback functions.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.Source
  alias MarketMySpec.ProblemDiscovery.Source.Upwork

  spex "Source.Upwork implements the Source behaviour" do
    scenario "Source.Upwork declares the Source behaviour and exports every required callback" do
      given_ "the Source behaviour exists in the project", context do
        assert function_exported?(Source, :behaviour_info, 1) or
                 Code.ensure_loaded?(Source),
               "expected Source behaviour module to be loadable"

        {:ok, context}
      end

      when_ "introspecting Source.Upwork's declared behaviours and exports", context do
        Code.ensure_loaded(Upwork)

        declared_behaviours =
          Upwork.module_info(:attributes)
          |> Keyword.get_values(:behaviour)
          |> List.flatten()

        callbacks = Source.behaviour_info(:callbacks)

        {:ok,
         Map.merge(context, %{
           declared_behaviours: declared_behaviours,
           callbacks: callbacks
         })}
      end

      then_ "Source.Upwork declares @behaviour Source", context do
        assert Source in context.declared_behaviours,
               "expected Source.Upwork to declare @behaviour MarketMySpec.ProblemDiscovery.Source; declared: #{inspect(context.declared_behaviours)}"

        {:ok, context}
      end

      then_ "Source.Upwork exports every callback the Source behaviour defines", context do
        for {fun, arity} <- context.callbacks do
          assert function_exported?(Upwork, fun, arity),
                 "expected Source.Upwork to export #{fun}/#{arity} per Source behaviour"
        end

        {:ok, context}
      end
    end
  end
end
