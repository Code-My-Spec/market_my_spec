defmodule MarketMySpec.Linter.Config do
  @moduledoc """
  Per-account stored Vale `.vale.ini` text. One row per account; absence
  of a row means "no Vale configuration."
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Accounts.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          vale_ini: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "linter_configs" do
    field :vale_ini, :string
    belongs_to :account, Account
    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(config, attrs) do
    config
    |> cast(attrs, [:account_id, :vale_ini])
    |> validate_required([:account_id, :vale_ini])
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:account_id)
  end
end
