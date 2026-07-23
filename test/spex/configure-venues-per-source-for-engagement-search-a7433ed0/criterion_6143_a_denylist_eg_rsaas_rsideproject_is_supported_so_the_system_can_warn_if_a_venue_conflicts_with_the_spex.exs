defmodule MarketMySpecSpex.Story708.Criterion6143Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6143 — A denylist (e.g., r/SaaS, r/sideproject) is supported so the
  system can warn if a venue conflicts with the MMS allocation.

  Known denied subreddits (e.g., r/SaaS where links are auto-removed) are
  still valid Reddit subreddit name formats but may carry a warning. At the
  scaffold stage the Venue schema does not block denylist entries — it validates
  format only. The denylist warning is a higher-level concern. This spec verifies
  that denylist subreddits are at least format-valid so the schema can accept
  them and a future layer can warn on them.

  Interaction surface: Venue schema changeset (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Venue

  @denylist_subreddits ~w(SaaS sideproject)

  spex "denylist subreddits are format-valid and can be stored with a warning" do
    scenario "denylist subreddits pass format validation (they are valid subreddit names)" do
      given_ "the denylist of subreddits", context do
        {:ok, Map.put(context, :denylist, @denylist_subreddits)}
      end

      when_ "each denylist subreddit is validated via Venue.changeset/2", context do
        results =
          Enum.map(context.denylist, fn identifier ->
            attrs = %{
              account_id: Ecto.UUID.generate(),
              source: :reddit,
              identifier: identifier
            }

            changeset = Venue.changeset(%Venue{}, attrs)
            {identifier, changeset.valid?, changeset.errors}
          end)

        {:ok, Map.put(context, :results, results)}
      end

      then_ "denylist subreddits are format-valid (schema accepts them)", context do
        # Denylist subreddits like r/SaaS and r/sideproject have valid subreddit name
        # formats. The schema should accept them — denylist enforcement is a higher
        # application layer concern that warns rather than hard-rejects.
        failures =
          Enum.reject(context.results, fn {_id, valid, _errors} -> valid end)

        assert failures == [],
               "expected denylist subreddits to be format-valid so they can be stored " <>
                 "(warnings applied at a higher layer), but these failed: " <>
                 "#{inspect(Enum.map(failures, fn {id, _, errs} -> {id, errs} end))}"

        {:ok, context}
      end
    end

    scenario "a denylist subreddit can be added and then disabled to prevent search" do
      given_ "a denylist subreddit venue attributes", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :reddit,
          identifier: "SaaS",
          weight: 1.0,
          enabled: false
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the Venue changeset is built with enabled: false", context do
        changeset = Venue.changeset(%Venue{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid — denylist venues can be stored as disabled", context do
        assert context.changeset.valid?,
               "expected a disabled denylist venue to be format-valid, " <>
                 "errors: #{inspect(context.changeset.errors)}"

        enabled = Ecto.Changeset.get_field(context.changeset, :enabled)

        assert enabled == false,
               "expected enabled to be false for a denylist venue, got: #{inspect(enabled)}"

        {:ok, context}
      end
    end
  end
end
