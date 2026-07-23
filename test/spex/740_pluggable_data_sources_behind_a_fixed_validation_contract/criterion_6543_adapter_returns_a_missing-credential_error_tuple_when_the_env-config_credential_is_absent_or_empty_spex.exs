defmodule MarketMySpecSpex.Story740.Criterion6543Spex do
  @moduledoc """
  Story 740 — Pluggable data sources behind a fixed validation contract
  Criterion 6543 — Adapter returns a missing-credential error tuple when the
  env-config credential is absent or empty (no fallback, no silent failure).

  When Application config holds no api_key and no env var override is
  set, Source.Upwork.search/2 must return an :error tuple indicating the
  missing credential. No fallback to a default, no swallowed errors, no
  successful HTTP call against an empty Bearer header.

  Interaction surface: function-level test on Source.Upwork with
  Application config explicitly cleared.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.Source.Upwork

  spex "Adapter returns a missing-credential error when env config is absent" do
    scenario "With no api_key in Application config and no opt override, search/2 returns {:error, :missing_upwork_api_key}" do
      given_ "Application config has no api_key set for the Upwork adapter", context do
        original = Application.get_env(:market_my_spec, Upwork, [])

        Application.put_env(
          :market_my_spec,
          Upwork,
          Keyword.delete(original, :api_key)
        )

        original_env = System.get_env("UPWORK_API_KEY")
        System.delete_env("UPWORK_API_KEY")

        on_exit(fn ->
          Application.put_env(:market_my_spec, Upwork, original)
          if original_env, do: System.put_env("UPWORK_API_KEY", original_env)
        end)

        {:ok, context}
      end

      when_ "the agent invokes Source.Upwork.search/2 without an api_key opt", context do
        result = Upwork.search(%{source: "upwork", query: "anything"}, limit: 1)

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the adapter returns an explicit missing-credential error tuple",
            context do
        assert {:error, reason} = context.result,
               "expected an :error tuple when credential is absent; got: #{inspect(context.result)}"

        assert reason in [:missing_upwork_api_key, :missing_credential, :missing_integration],
               "expected the error reason to name the missing credential; got: #{inspect(reason)}"
        {:ok, context}
      end
    end
  end
end
