defmodule MarketMySpec.Integrations.Integration do
  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Encrypted.Binary
  alias MarketMySpec.Users.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          provider: atom() | nil,
          access_token: binary() | nil,
          refresh_token: binary() | nil,
          expires_at: DateTime.t() | nil,
          granted_scopes: [String.t()] | nil,
          provider_metadata: map() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @providers Application.compile_env(:market_my_spec, :integration_providers, [:github])

  schema "integrations" do
    field :provider, Ecto.Enum, values: @providers
    field :access_token, Binary
    field :refresh_token, Binary
    field :expires_at, :utc_datetime_usec
    field :granted_scopes, {:array, :string}, default: []
    field :provider_metadata, :map, default: %{}

    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [:user_id, :provider, :access_token, :refresh_token, :expires_at, :granted_scopes, :provider_metadata])
    |> validate_required([:user_id, :provider, :access_token, :expires_at])
    |> assoc_constraint(:user)
    |> unique_constraint([:user_id, :provider], name: :integrations_user_id_provider_index)
  end

  def expired?(%__MODULE__{expires_at: expires_at}) do
    now = DateTime.utc_now()
    DateTime.compare(now, expires_at) != :lt
  end

  def has_refresh_token?(%__MODULE__{refresh_token: nil}), do: false
  def has_refresh_token?(%__MODULE__{refresh_token: ""}), do: false
  def has_refresh_token?(%__MODULE__{refresh_token: _token}), do: true
end
