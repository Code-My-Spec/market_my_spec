defmodule MarketMySpec.Agencies do
  @moduledoc """
  Context module for agency account features: client account creation
  (originator path), invited access grants, client portfolio queries, and
  agency-driven access checks.
  """

  alias MarketMySpec.Accounts.{Account, AccountsRepository}
  alias MarketMySpec.Agencies.AgenciesRepository
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.User

  @doc """
  Lists all active agency-client grants for an agency account, with the client
  account preloaded on each grant.
  """
  @spec list_grants_for_agency(binary()) :: list()
  def list_grants_for_agency(agency_account_id) do
    AgenciesRepository.list_grants_for_agency(agency_account_id)
  end

  @doc """
  Creates a new client account and an agency-originated grant in a single transaction.
  Used when an agency owner creates a client from /agency/clients/new.

  Returns {:ok, {client_account, grant}} on success.
  """
  @spec create_client_account_with_originated_grant(Account.t(), map(), integer()) ::
          {:ok, {Account.t(), any()}} | {:error, any()}
  def create_client_account_with_originated_grant(
        %Account{} = agency_account,
        client_attrs,
        created_by_user_id
      ) do
    Repo.transaction(fn ->
      with {:ok, client_account} <-
             AccountsRepository.create_account_with_owner(client_attrs, created_by_user_id),
           {:ok, grant} <-
             AgenciesRepository.create_originated_grant(%{
               agency_account_id: agency_account.id,
               client_account_id: client_account.id,
               access_level: "account_manager",
               created_by_user_id: created_by_user_id
             }) do
        {client_account, grant}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Creates an invited agency-client grant. Called when a client owner uses the
  grant-agency-access form on /accounts to invite an agency.

  Resolves the agency by slug before creating the grant.
  Returns {:ok, grant} or {:error, reason}.
  """
  @spec invite_agency_grant(Account.t(), String.t(), String.t(), integer()) ::
          {:ok, any()} | {:error, any()}
  def invite_agency_grant(
        %Account{} = client_account,
        agency_slug,
        access_level,
        created_by_user_id
      ) do
    case AgenciesRepository.get_agency_by_slug(agency_slug) do
      nil ->
        {:error, :agency_not_found}

      agency_account ->
        if AgenciesRepository.grant_exists?(agency_account.id, client_account.id) do
          {:error, :already_granted}
        else
          AgenciesRepository.create_invited_grant(%{
            agency_account_id: agency_account.id,
            client_account_id: client_account.id,
            access_level: access_level,
            created_by_user_id: created_by_user_id
          })
        end
    end
  end

  @doc """
  Revokes an existing invited agency-client grant. Only non-originator grants can be revoked.
  Returns {:ok, grant} or {:error, reason}.
  """
  @spec revoke_grant(binary()) :: {:ok, any()} | {:error, any()}
  def revoke_grant(grant_id), do: AgenciesRepository.revoke_grant(grant_id)

  @doc """
  Checks whether the given user has agency-granted access to the specified client account.
  Used to validate context-switching authorization.

  Returns true if any agency the user belongs to has an active grant for that client account.
  """
  @spec user_has_agency_access_to_client?(User.t(), binary()) :: boolean()
  def user_has_agency_access_to_client?(%User{} = user, client_account_id) do
    AgenciesRepository.user_has_agency_access_to_client?(user.id, client_account_id)
  end

  @doc """
  Updates an agency's branding fields — logo URL, primary color, secondary color.
  Validates HTTPS URL format and #rrggbb color format. Empty/nil values clear the fields.
  """
  @spec update_branding(Account.t(), map()) ::
          {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
  def update_branding(%Account{} = agency, attrs) do
    agency
    |> Account.branding_changeset(attrs)
    |> Repo.update()
  end
end
