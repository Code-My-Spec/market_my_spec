defmodule MarketMySpecSpex.Story740.Criterion6538Spex do
  @moduledoc """
  Story 740 — Pluggable data sources behind a fixed validation contract
  Criterion 6538 — UpworkAdapter normalizes posting + client metadata as raw values.

  The Source.Upwork adapter must return JobPosting attribute maps with
  RAW values from Upwork (title, description, total_spent_cents,
  hire_rate, url, source_id) — not computed signals, not summary fields.
  Computed signals are Score's job, not the adapter's.

  Interaction surface: direct function call on Source.Upwork.search/2
  against a recorded Upwork (or Apify) response. Asserts the returned
  attribute maps carry the raw fields only.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.Source.Upwork
  alias MarketMySpecSpex.ProblemDiscoveryHelpers

  @raw_fields ~w(source source_id title description url total_spent_cents hire_rate)a

  spex "UpworkAdapter returns raw posting + client metadata fields only" do
    scenario "Calling Source.Upwork.search/2 returns attribute maps with raw fields, no computed signals" do
      given_ "the Upwork adapter is configured with a test API key", context do
        {:ok, Map.put(context, :saved_search, "upwork|vendor onboarding")}
      end

      when_ "the agent invokes Source.Upwork.search/2 against the saved search",
            context do
        result =
          ProblemDiscoveryHelpers.with_apify_cassette("criterion_6538", fn ->
            Upwork.search(context.saved_search, limit: 5)
          end)

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the adapter returns {:ok, [posting_attrs]} with each posting carrying only the raw field set",
            context do
        assert {:ok, postings} = context.result

        for posting <- postings do
          posting_keys = posting |> Map.keys() |> Enum.sort()

          assert Enum.all?(posting_keys, fn k -> k in @raw_fields end),
                 "expected only raw fields #{inspect(@raw_fields)}; got: #{inspect(posting_keys)}"

          refute Map.has_key?(posting, :score),
                 "adapter must not emit computed Score fields (score is Score's job)"

          refute Map.has_key?(posting, :verdict),
                 "adapter must not emit computed verdict fields (verdict is Red-team's job)"

          refute Map.has_key?(posting, :embedding),
                 "adapter must not emit embeddings (Gather attaches embeddings post-fetch)"
        end

        {:ok, context}
      end
    end
  end
end
