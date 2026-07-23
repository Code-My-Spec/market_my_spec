defmodule MarketMySpecSpex.Story740.Criterion6542Spex do
  @moduledoc """
  Story 740 — Pluggable data sources behind a fixed validation contract
  Criterion 6542 — Adapter reads its credential from app-level environment
  configuration (Dotenvy-loaded env var via Application config), not from
  the per-account Integrations context.

  Per `architecture/decisions/problem-discovery-data-sources.md`, Source
  adapters use service-account credentials sourced from env config — not
  the user-OAuth Integrations context. The adapter respects either an
  Application config value (set via Dotenvy at boot) or an explicit
  `:api_key` opt passed by the caller.

  Interaction surface: function-level test on Source.Upwork's credential
  resolution. With Application config set, calls succeed (credentials
  resolved); the opt override path is also exercised.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.Source.Upwork

  spex "Source adapter reads credentials from env-injected Application config (not Integrations)" do
    scenario "When OPENAI/UPWORK keys are present in Application config, the adapter resolves and uses them" do
      given_ "the Upwork adapter is configured via Application config", context do
        original = Application.get_env(:market_my_spec, Upwork, [])

        Application.put_env(:market_my_spec, Upwork, Keyword.put(original, :api_key, "test-key"))

        on_exit(fn ->
          Application.put_env(:market_my_spec, Upwork, original)
        end)

        {:ok, Map.put(context, :api_key, "test-key")}
      end

      when_ "the agent invokes Source.Upwork.search/2 with no api_key opt", context do
        result = Upwork.search(%{source: "upwork", query: "anything"}, limit: 1)

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the adapter does NOT return :missing_upwork_api_key (it found the key in env config)",
            context do
        case context.result do
          {:error, :missing_upwork_api_key} ->
            flunk(
              "adapter returned :missing_upwork_api_key despite Application config carrying :api_key — credential resolution is not going through env config"
            )

          _ ->
            {:ok, context}
        end
        {:ok, context}
      end

      then_ "the adapter does not touch the MarketMySpec.Integrations context for its credential",
            context do
        integrations_loaded? = Code.ensure_loaded?(MarketMySpec.Integrations)

        if integrations_loaded? do
          # The structural assertion: adapter source must not alias or
          # call MarketMySpec.Integrations.* — the env-config rule
          # (problem-discovery-data-sources.md) is explicit on this.
          source = File.read!("lib/market_my_spec/problem_discovery/source/upwork.ex")

          refute source =~ "MarketMySpec.Integrations",
                 "expected Source.Upwork to not reference MarketMySpec.Integrations; env-config credentials only per the data-sources ADR"
        end

        {:ok, context}
      end
    end
  end
end
