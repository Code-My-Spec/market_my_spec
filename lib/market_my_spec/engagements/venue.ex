defmodule MarketMySpec.Engagements.Venue do
  @moduledoc """
  Per-account venue record.

  A venue represents a single platform location the engagement-finder will
  search — a subreddit for Reddit, or a category (with optional tag filter)
  for ElixirForum. Each venue is scoped to an account and carries a weight
  multiplier used during result ranking and an enabled flag that controls
  whether the venue participates in searches.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Engagements.Source.ElixirForum
  alias MarketMySpec.Engagements.Source.Reddit

  @type source :: :reddit | :elixirforum

  @type t :: %__MODULE__{
          id: integer() | nil,
          account_id: Ecto.UUID.t() | nil,
          source: source() | nil,
          identifier: String.t() | nil,
          weight: float() | nil,
          enabled: boolean() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "venues" do
    field :source, Ecto.Enum, values: [:reddit, :elixirforum]
    field :identifier, :string
    field :weight, :float, default: 1.0
    field :enabled, :boolean, default: true

    belongs_to :account, Account, type: :binary_id

    timestamps()
  end

  @doc """
  Changeset for creating or updating a venue.

  Validates required fields and delegates identifier validation to the
  appropriate source adapter via `validate_venue/1`.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(venue, attrs) do
    venue
    |> cast(attrs, [:account_id, :source, :identifier, :weight, :enabled])
    |> validate_required([:account_id, :source, :identifier])
    |> validate_number(:weight, greater_than: 0)
    |> validate_identifier()
    |> assoc_constraint(:account)
  end

  defp validate_identifier(changeset) do
    source = get_field(changeset, :source)
    identifier = get_field(changeset, :identifier)
    do_validate_identifier(changeset, source, identifier)
  end

  defp do_validate_identifier(changeset, nil, _identifier), do: changeset
  defp do_validate_identifier(changeset, _source, nil), do: changeset

  defp do_validate_identifier(changeset, :reddit, identifier) do
    case Reddit.validate_venue(identifier) do
      :ok -> changeset
      {:error, message} -> add_error(changeset, :identifier, message)
    end
  end

  defp do_validate_identifier(changeset, :elixirforum, identifier) do
    case ElixirForum.validate_venue(identifier) do
      :ok -> changeset
      {:error, message} -> add_error(changeset, :identifier, message)
    end
  end
end
