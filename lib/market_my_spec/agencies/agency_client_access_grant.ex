defmodule MarketMySpec.Agencies.AgencyClientAccessGrant do
  @moduledoc """
  Represents an access grant between an agency account and a client account.

  Originators:
  - "agency" — the agency created the client account and thus owns the relationship
  - "client" — the client owner invited the agency into their account

  Status values:
  - "accepted" — the grant is active
  - "pending" — awaiting acceptance (client-originated invites start here)
  - "revoked" — the grant has been revoked by either party

  Access levels:
  - "read_only" — agency can view but not modify client data
  - "account_manager" — agency can manage the client account
  - "admin" — agency has full admin access to the client account
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_access_levels ~w(read_only account_manager admin)
  @valid_statuses ~w(pending accepted revoked)
  @valid_originators ~w(agency client)

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "agency_client_grants" do
    field :access_level, :string, default: "read_only"
    field :status, :string, default: "accepted"
    field :originator, :string

    belongs_to :agency_account, MarketMySpec.Accounts.Account, type: :binary_id
    belongs_to :client_account, MarketMySpec.Accounts.Account, type: :binary_id
    belongs_to :created_by_user, MarketMySpec.Users.User

    timestamps()
  end

  @doc "Changeset for creating a new agency-client grant."
  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [
      :agency_account_id,
      :client_account_id,
      :access_level,
      :status,
      :originator,
      :created_by_user_id
    ])
    |> validate_required([:agency_account_id, :client_account_id, :access_level, :originator])
    |> validate_inclusion(:access_level, @valid_access_levels,
      message: "must be one of: #{Enum.join(@valid_access_levels, ", ")}"
    )
    |> validate_inclusion(:status, @valid_statuses,
      message: "must be one of: #{Enum.join(@valid_statuses, ", ")}"
    )
    |> validate_inclusion(:originator, @valid_originators,
      message: "must be one of: #{Enum.join(@valid_originators, ", ")}"
    )
    |> assoc_constraint(:agency_account)
    |> assoc_constraint(:client_account)
    |> unique_constraint([:agency_account_id, :client_account_id],
      name: :agency_client_grants_agency_account_id_client_account_id_index,
      message: "already has access — this agency-client pair already exists"
    )
  end
end
