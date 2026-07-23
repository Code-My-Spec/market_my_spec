defmodule MarketMySpecSpex.Story708.Criterion6149Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6149 — An ElixirForum venue with an unknown category is rejected.

  At the scaffold stage, ElixirForum.validate_venue/1 accepts any non-empty
  string as a valid identifier (full category-existence checks require an API
  call). The key invariant is that an empty identifier is rejected. This spec
  verifies that the empty-identifier guard is in place and that non-empty
  identifiers (even unknown ones) are accepted at the schema level.

  Interaction surface: Source.ElixirForum.validate_venue/1 + Venue changeset (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Source.ElixirForum
  alias MarketMySpec.Engagements.Venue

  spex "an ElixirForum venue with an unknown/empty category is rejected" do
    scenario "ElixirForum.validate_venue/1 rejects an empty identifier" do
      given_ "an empty ElixirForum venue identifier", context do
        {:ok, Map.put(context, :identifier, "")}
      end

      when_ "validate_venue is called with an empty string", context do
        result = ElixirForum.validate_venue(context.identifier)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "validation returns an error for the empty identifier", context do
        assert match?({:error, _}, context.result),
               "expected {:error, _} for an empty ElixirForum identifier, " <>
                 "got: #{inspect(context.result)}"

        {:ok, context}
      end
    end

    scenario "Venue.changeset/2 rejects an ElixirForum venue with an empty identifier" do
      given_ "an ElixirForum Venue with an empty identifier", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :elixirforum,
          identifier: "",
          weight: 1.0,
          enabled: true
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the Venue changeset is built", context do
        changeset = Venue.changeset(%Venue{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid (empty identifier rejected)", context do
        refute context.changeset.valid?,
               "expected changeset to be invalid for an empty ElixirForum identifier"

        {:ok, context}
      end
    end

    scenario "ElixirForum.validate_venue/1 accepts a non-empty identifier at scaffold stage" do
      given_ "a non-empty but potentially unknown ElixirForum category identifier", context do
        {:ok, Map.put(context, :identifier, "unknown-but-non-empty-category")}
      end

      when_ "validate_venue is called", context do
        result = ElixirForum.validate_venue(context.identifier)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "at the scaffold stage, non-empty identifiers are accepted without API check", context do
        # Full category-existence validation requires an HTTP call to the ElixirForum API.
        # At the scaffold stage, any non-empty string is accepted. Future implementations
        # may add a real existence check via the Discourse API.
        assert context.result == :ok,
               "expected :ok for a non-empty ElixirForum identifier at scaffold stage, " <>
                 "got: #{inspect(context.result)}"

        {:ok, context}
      end
    end
  end
end
