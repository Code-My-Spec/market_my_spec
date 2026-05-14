defmodule MarketMySpecSpex.Story708.Criterion6146Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6146 — Weight and enabled flag take sensible defaults.

  When a venue is created without specifying weight or enabled, the schema
  applies defaults: weight defaults to 1.0 and enabled defaults to true.
  These defaults mean a new venue participates in search at neutral weight
  without requiring explicit configuration.

  Interaction surface: Venue schema changeset (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Venue

  spex "weight and enabled flag take sensible defaults" do
    scenario "a venue built without weight defaults to 1.0" do
      given_ "venue attributes without an explicit weight", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :reddit,
          identifier: "elixir"
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the Venue changeset is built", context do
        changeset = Venue.changeset(%Venue{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid", context do
        assert context.changeset.valid?,
               "expected changeset to be valid with default weight, " <>
                 "errors: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end

      then_ "the weight defaults to 1.0", context do
        weight = Ecto.Changeset.get_field(context.changeset, :weight)

        assert weight == 1.0,
               "expected weight to default to 1.0, got: #{inspect(weight)}"

        {:ok, context}
      end
    end

    scenario "a venue built without enabled defaults to true" do
      given_ "venue attributes without an explicit enabled flag", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :elixirforum,
          identifier: "phoenix-forum"
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the Venue changeset is built", context do
        changeset = Venue.changeset(%Venue{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid", context do
        assert context.changeset.valid?,
               "expected changeset to be valid with default enabled, " <>
                 "errors: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end

      then_ "enabled defaults to true", context do
        enabled = Ecto.Changeset.get_field(context.changeset, :enabled)

        assert enabled == true,
               "expected enabled to default to true, got: #{inspect(enabled)}"

        {:ok, context}
      end
    end

    scenario "a venue built with all defaults produces a ready-to-search venue" do
      given_ "minimal venue attributes (source and identifier only)", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :reddit,
          identifier: "elixir"
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the Venue changeset is built", context do
        changeset = Venue.changeset(%Venue{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the venue is valid, enabled, and has neutral weight — ready for search", context do
        assert context.changeset.valid?,
               "expected minimal venue to be valid with sensible defaults"

        weight = Ecto.Changeset.get_field(context.changeset, :weight)
        enabled = Ecto.Changeset.get_field(context.changeset, :enabled)

        assert weight == 1.0, "expected default weight 1.0"
        assert enabled == true, "expected default enabled true"

        {:ok, context}
      end
    end
  end
end
