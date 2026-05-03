defmodule MarketMySpec.Accounts.Invitation do
  @moduledoc """
  Invitation schema with SHA256 token hashing.

  The raw token is URL-safe base64 encoded and sent to the invitee.
  Only the SHA256 hash is stored in the database. The virtual `token`
  field is populated after insert when the encoded token is available.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Users.User

  @hash_algorithm :sha256
  @rand_size 32

  @type status :: :pending | :accepted | :declined
  @type role :: :owner | :admin | :member

  @type t :: %__MODULE__{
          id: integer() | nil,
          token: String.t() | nil,
          token_hash: binary() | nil,
          email: String.t() | nil,
          role: role() | nil,
          status: status() | nil,
          expires_at: DateTime.t() | nil,
          accepted_at: DateTime.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          invited_by_user_id: integer() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          invited_by: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "invitations" do
    field :token, :string, virtual: true
    field :token_hash, :binary
    field :email, :string
    field :role, Ecto.Enum, values: [:owner, :admin, :member]
    field :status, Ecto.Enum, values: [:pending, :accepted, :declined], default: :pending
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime

    belongs_to :account, Account, type: :binary_id
    belongs_to :invited_by, User, foreign_key: :invited_by_user_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a new or existing invitation.
  """
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:token_hash, :email, :role, :expires_at, :account_id, :invited_by_user_id])
    |> maybe_force_status(attrs)
    |> validate_required([:email, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email address")
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:invited_by_user_id)
    |> unique_constraint(:token_hash)
  end

  @doc """
  Marks an invitation as accepted.
  """
  def accept_changeset(%__MODULE__{} = invitation) do
    invitation
    |> change(status: :accepted, accepted_at: DateTime.utc_now(:second))
    |> validate_required([:status])
  end

  @doc """
  Generates a cryptographically secure token and returns
  `{encoded_token, changeset}`.

  The encoded token is URL-safe base64. The changeset has the
  hashed token set and is ready to be merged with other attributes.
  """
  def build_token(%__MODULE__{} = invitation) do
    raw_token = :crypto.strong_rand_bytes(@rand_size)
    encoded_token = Base.url_encode64(raw_token, padding: false)
    hashed = :crypto.hash(@hash_algorithm, raw_token)
    changeset = change(invitation, token_hash: hashed)
    {encoded_token, changeset}
  end

  @doc """
  Returns the SHA-256 hash for a URL-safe base64-encoded token.

  Used to look up invitations by the token included in the acceptance URL.
  """
  def token_hash(encoded_token) when is_binary(encoded_token) do
    case Base.url_decode64(encoded_token, padding: false) do
      {:ok, raw} -> :crypto.hash(@hash_algorithm, raw)
      :error -> :crypto.hash(@hash_algorithm, encoded_token)
    end
  end

  @doc """
  Marks an invitation as declined.
  """
  def decline_changeset(%__MODULE__{} = invitation) do
    invitation
    |> change(status: :declined)
    |> validate_required([:status])
  end

  defp maybe_force_status(changeset, %{status: status}),
    do: force_change(changeset, :status, status)

  defp maybe_force_status(changeset, _attrs), do: changeset
end
