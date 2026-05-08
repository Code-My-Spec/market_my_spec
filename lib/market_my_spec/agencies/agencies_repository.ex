defmodule MarketMySpec.Agencies.AgenciesRepository do
  @moduledoc """
  Database access layer for AgencyClientAccessGrant records and agency lookups
  used by the agency-client grant flows.
  """

  import Ecto.Query, warn: false

  alias MarketMySpec.Accounts.{Account, Member}
  alias MarketMySpec.Agencies.AgencyClientAccessGrant
  alias MarketMySpec.Repo

  @doc """
  Lists all active grants for an agency, with the associated client account preloaded.
  Returns grants with status "accepted" only.
  """
  @spec list_grants_for_agency(binary()) :: [AgencyClientAccessGrant.t()]
  def list_grants_for_agency(agency_account_id) do
    from(g in AgencyClientAccessGrant,
      where: g.agency_account_id == ^agency_account_id and g.status == "accepted",
      preload: [:client_account],
      order_by: [asc: g.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Creates an agency-originated grant. Used when an agency creates a new client account
  from /agency/clients/new. The originator is set to "agency" and status to "accepted".
  """
  @spec create_originated_grant(map()) ::
          {:ok, AgencyClientAccessGrant.t()} | {:error, Ecto.Changeset.t()}
  def create_originated_grant(attrs) do
    attrs_with_defaults = Map.merge(%{originator: "agency", status: "accepted"}, attrs)

    %AgencyClientAccessGrant{}
    |> AgencyClientAccessGrant.changeset(attrs_with_defaults)
    |> Repo.insert()
  end

  @doc """
  Creates a client-originated (invited) grant. Used when a client owner grants agency
  access from /accounts. Originator is "client"; status defaults to "accepted" (auto-accepted).
  """
  @spec create_invited_grant(map()) ::
          {:ok, AgencyClientAccessGrant.t()} | {:error, Ecto.Changeset.t()}
  def create_invited_grant(attrs) do
    attrs_with_defaults = Map.merge(%{originator: "client", status: "accepted"}, attrs)

    %AgencyClientAccessGrant{}
    |> AgencyClientAccessGrant.changeset(attrs_with_defaults)
    |> Repo.insert()
  end

  @doc """
  Looks up an agency account by slug for grant creation.
  """
  @spec get_agency_by_slug(String.t()) :: Account.t() | nil
  def get_agency_by_slug(slug) do
    Repo.get_by(Account, slug: slug, type: :agency)
  end

  @doc """
  Retrieves a grant by ID.
  """
  @spec get_grant(binary()) :: AgencyClientAccessGrant.t() | nil
  def get_grant(id), do: Repo.get(AgencyClientAccessGrant, id)

  @doc """
  Revokes a grant by setting its status to "revoked".
  Only non-originator ("client"-originated) grants may be revoked.
  """
  @spec revoke_grant(binary()) ::
          {:ok, AgencyClientAccessGrant.t()} | {:error, :not_found} | {:error, :not_revokable}
  def revoke_grant(grant_id) do
    case Repo.get(AgencyClientAccessGrant, grant_id) do
      nil ->
        {:error, :not_found}

      %AgencyClientAccessGrant{originator: "agency"} ->
        {:error, :not_revokable}

      grant ->
        grant
        |> AgencyClientAccessGrant.changeset(%{status: "revoked"})
        |> Repo.update()
    end
  end

  @doc """
  Checks whether a grant already exists for the given agency-client pair.
  """
  @spec grant_exists?(binary(), binary()) :: boolean()
  def grant_exists?(agency_account_id, client_account_id) do
    Repo.exists?(
      from g in AgencyClientAccessGrant,
        where:
          g.agency_account_id == ^agency_account_id and g.client_account_id == ^client_account_id
    )
  end

  @doc """
  Returns true if any agency account that the given user belongs to has an accepted grant
  for the specified client account. Used to authorize context-switching and read access.
  """
  @spec user_has_agency_access_to_client?(integer(), binary()) :: boolean()
  def user_has_agency_access_to_client?(user_id, client_account_id) do
    Repo.exists?(
      from g in AgencyClientAccessGrant,
        join: m in Member,
        on: m.account_id == g.agency_account_id and m.user_id == ^user_id,
        where: g.client_account_id == ^client_account_id and g.status == "accepted"
    )
  end

  @doc """
  Returns the access level for the given user on the specified client account via an agency grant.
  Returns the access level string (e.g. "read_only", "account_manager", "admin") or nil if none.
  """
  @spec get_user_agency_access_level(integer(), binary()) :: String.t() | nil
  def get_user_agency_access_level(user_id, client_account_id) do
    from(g in AgencyClientAccessGrant,
      join: m in Member,
      on: m.account_id == g.agency_account_id and m.user_id == ^user_id,
      where: g.client_account_id == ^client_account_id and g.status == "accepted",
      select: g.access_level,
      limit: 1
    )
    |> Repo.one()
  end
end
