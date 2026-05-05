defmodule MarketMySpec.Accounts do
  @moduledoc """
  Context module for account management, membership, agency-client grants,
  and invitation workflows.
  """

  alias MarketMySpec.Accounts.{Account, AccountsRepository, AgencyClientGrantsRepository}
  alias MarketMySpec.Accounts.{InvitationNotifier, InvitationRepository, MembersRepository}
  alias MarketMySpec.Authorization
  alias MarketMySpec.Repo
  alias MarketMySpec.Users
  alias MarketMySpec.Users.Scope
  alias MarketMySpec.Users.User

  def subscribe_account(%Scope{} = scope) do
    key = scope.user.id
    Phoenix.PubSub.subscribe(MarketMySpec.PubSub, "user:#{key}:account")
  end

  def subscribe_member(%Scope{} = scope) do
    key = scope.user.id
    Phoenix.PubSub.subscribe(MarketMySpec.PubSub, "user:#{key}:member")
  end

  defp broadcast_account(%Scope{} = scope, message) do
    key = scope.user.id
    Phoenix.PubSub.broadcast(MarketMySpec.PubSub, "user:#{key}:account", message)
  end

  defp broadcast_member(%Scope{} = scope, message) do
    key = scope.user.id
    Phoenix.PubSub.broadcast(MarketMySpec.PubSub, "user:#{key}:member", message)
  end

  @doc """
  Creates a default individual account for a newly confirmed user.
  The user is set as the owner. Used as part of the sign-up confirmation flow.
  """
  def create_default_individual_account(user) do
    email_prefix =
      user.email
      |> String.split("@")
      |> List.first()

    account_name = "#{email_prefix}'s workspace"

    attrs = %{name: account_name, type: :individual}

    AccountsRepository.create_account_with_owner(attrs, user.id)
  end

  def list_accounts(%Scope{} = scope) do
    MembersRepository.list_user_accounts_with_role(scope.user.id)
  end

  def get_account(%Scope{} = scope, id) do
    case AccountsRepository.get_account(id) do
      nil ->
        nil

      account ->
        case Authorization.authorize(:read_account, scope, account.id) do
          false -> nil
          true -> account
        end
    end
  end

  def get_account!(%Scope{} = scope, id) do
    account = AccountsRepository.get_account!(id)
    Authorization.authorize!(:read_account, scope, account.id)
    account
  end

  def create_account(%Scope{} = scope, attrs) do
    with {:ok, account} <- AccountsRepository.create_account_with_owner(attrs, scope.user.id) do
      broadcast_account(scope, {:created, account})
      {:ok, account}
    end
  end

  def update_account(%Scope{} = scope, %Account{} = account, attrs) do
    Authorization.authorize!(:manage_account, scope, account.id)

    with {:ok, account} <- AccountsRepository.update_account(account, attrs) do
      broadcast_account(scope, {:updated, account})
      {:ok, account}
    end
  end

  def delete_account(%Scope{} = scope, %Account{} = account) do
    Authorization.authorize!(:manage_account, scope, account.id)

    with {:ok, account} <- AccountsRepository.delete_account(account) do
      broadcast_account(scope, {:deleted, account})
      {:ok, account}
    end
  end

  def change_account(%Scope{} = scope, %Account{} = account, attrs \\ %{}) do
    Authorization.authorize!(:manage_account, scope, account.id)
    Account.changeset(account, attrs)
  end

  def list_account_members(%Scope{} = scope, account_id) do
    Authorization.authorize!(:read_account, scope, account_id)
    MembersRepository.list_account_members(account_id)
  end

  def add_user_to_account(%Scope{} = scope, user_id, account_id, role \\ :member) do
    Authorization.authorize!(:manage_account, scope, account_id)

    with {:ok, member} <- MembersRepository.add_user_to_account(user_id, account_id, role) do
      broadcast_member(scope, {:created, member})
      {:ok, member}
    end
  end

  def remove_user_from_account(%Scope{} = scope, user_id, account_id) do
    Authorization.authorize!(:manage_members, scope, account_id)

    with {:ok, member} <- MembersRepository.remove_user_from_account(user_id, account_id) do
      broadcast_member(scope, {:deleted, member})
      {:ok, member}
    end
  end

  def update_user_role(%Scope{} = scope, user_id, account_id, role) do
    Authorization.authorize!(:manage_members, scope, account_id)

    with {:ok, member} <- MembersRepository.update_user_role(user_id, account_id, role) do
      broadcast_member(scope, {:updated, member})
      {:ok, member}
    end
  end

  def get_user_role(%Scope{} = scope, user_id, account_id) do
    Authorization.authorize!(:read_account, scope, account_id)
    MembersRepository.get_user_role(user_id, account_id)
  end

  def user_has_account_access?(%Scope{} = scope, account_id) do
    MembersRepository.user_has_account_access?(scope.user.id, account_id)
  end

  def user_has_any_account?(%Users.User{} = user) do
    MembersRepository.user_has_any_account?(user.id)
  end

  @doc """
  Returns true if the user is a member of at least one agency-typed account.
  Used by the agency route type guard.
  """
  def user_has_agency_account?(%Users.User{} = user) do
    MembersRepository.user_has_agency_account?(user.id)
  end

  @doc """
  Returns the first agency account for which the user is a member, or nil.
  Used to populate the agency context on the dashboard.
  """
  def get_user_agency_account(%Users.User{} = user) do
    MembersRepository.get_user_agency_account(user.id)
  end

  # ---------------------------------------------------------------------------
  # Agency-Client Grants
  # ---------------------------------------------------------------------------

  @doc """
  Lists all active agency-client grants for an agency account, with the client
  account preloaded on each grant.
  """
  @spec list_grants_for_agency(binary()) :: list()
  def list_grants_for_agency(agency_account_id) do
    AgencyClientGrantsRepository.list_grants_for_agency(agency_account_id)
  end

  @doc """
  Creates a new client account and an agency-originated grant in a single transaction.
  Used when an agency owner creates a client from /agency/clients/new.

  Returns {:ok, {client_account, grant}} on success.
  """
  @spec create_client_account_with_originated_grant(Account.t(), map(), integer()) ::
          {:ok, {Account.t(), any()}} | {:error, any()}
  def create_client_account_with_originated_grant(%Account{} = agency_account, client_attrs, created_by_user_id) do
    Repo.transaction(fn ->
      with {:ok, client_account} <- AccountsRepository.create_account_with_owner(client_attrs, created_by_user_id),
           {:ok, grant} <-
             AgencyClientGrantsRepository.create_originated_grant(%{
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
  def invite_agency_grant(%Account{} = client_account, agency_slug, access_level, created_by_user_id) do
    case AgencyClientGrantsRepository.get_agency_by_slug(agency_slug) do
      nil ->
        {:error, :agency_not_found}

      agency_account ->
        if AgencyClientGrantsRepository.grant_exists?(agency_account.id, client_account.id) do
          {:error, :already_granted}
        else
          AgencyClientGrantsRepository.create_invited_grant(%{
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
  def revoke_grant(grant_id) do
    AgencyClientGrantsRepository.revoke_grant(grant_id)
  end

  # ---------------------------------------------------------------------------
  # Client Context Switching
  # ---------------------------------------------------------------------------

  @doc """
  Sets the active client account context for a user. This is used when an agency
  user "enters" a client account from the agency dashboard. The context is stored
  in the database so it persists across page navigations.

  Returns {:ok, user} or {:error, changeset}.
  """
  @spec set_active_client_context(User.t(), binary() | nil) :: {:ok, User.t()} | {:error, any()}
  def set_active_client_context(%User{} = user, account_id) do
    user
    |> User.client_context_changeset(account_id)
    |> Repo.update()
  end

  @doc """
  Returns the active client account for the given user, or nil if no context is set.
  Loads the account from the database using the user's active_client_account_id field.
  """
  @spec get_active_client_account(User.t()) :: Account.t() | nil
  def get_active_client_account(%User{active_client_account_id: nil}), do: nil

  def get_active_client_account(%User{active_client_account_id: account_id}) do
    AccountsRepository.get_account(account_id)
  end

  @doc """
  Checks whether the given user has agency-granted access to the specified client account.
  Used to validate context-switching authorization.

  Returns true if any agency the user belongs to has an active grant for that client account.
  """
  @spec user_has_agency_access_to_client?(User.t(), binary()) :: boolean()
  def user_has_agency_access_to_client?(%User{} = user, client_account_id) do
    AgencyClientGrantsRepository.user_has_agency_access_to_client?(user.id, client_account_id)
  end

  # ---------------------------------------------------------------------------
  # Invitations
  # ---------------------------------------------------------------------------

  def subscribe_invitations(%Scope{} = scope) do
    key = scope.user.id
    Phoenix.PubSub.subscribe(MarketMySpec.PubSub, "user:#{key}:invitations")
  end

  defp broadcast_invitation(%Scope{} = scope, message) do
    key = scope.user.id
    Phoenix.PubSub.broadcast(MarketMySpec.PubSub, "user:#{key}:invitations", message)
  end

  def invite_user(scope, account_id, email, role)
      when is_binary(email) and role in [:owner, :admin, :member] and not is_nil(account_id) do
    with :ok <- validate_manage_members_permission(scope, account_id),
         :ok <- validate_user_not_already_member(email, account_id),
         :ok <- validate_no_pending_invitation(email, account_id),
         {:ok, invitation} <- create_invitation(scope, account_id, email, role),
         :ok <- send_invitation_email(invitation) do
      broadcast_invitation(scope, {:created, invitation})
      {:ok, invitation}
    end
  end

  def accept_invitation(token, user_attrs) when is_binary(token) and is_map(user_attrs) do
    with {:ok, invitation} <- get_valid_invitation(token),
         {:ok, user} <- resolve_or_create_user(invitation, user_attrs),
         {:ok, member} <- accept_user_to_account(user, invitation),
         {:ok, _updated} <- InvitationRepository.accept(%Scope{}, invitation) do
      {:ok, {user, member}}
    end
  end

  def list_pending_invitations(scope, account_id) when not is_nil(account_id) do
    if Authorization.authorize(:read_account, scope, account_id) do
      InvitationRepository.list_pending_invitations(scope, account_id)
    else
      []
    end
  end

  def list_pending_invitations(_scope, nil), do: []

  def get_invitation_by_token(token) when is_binary(token) do
    InvitationRepository.get_by_token_hash(token)
  end

  def cancel_invitation(scope, account_id, invitation_id)
      when is_integer(invitation_id) and not is_nil(account_id) do
    with :ok <- validate_manage_members_permission(scope, account_id),
         invitation when not is_nil(invitation) <-
           InvitationRepository.get_invitation(scope, invitation_id),
         {:ok, cancelled} <- InvitationRepository.cancel(scope, invitation) do
      broadcast_invitation(scope, {:updated, cancelled})
      {:ok, cancelled}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def cleanup_expired_invitations do
    InvitationRepository.cleanup_expired_invitations(30)
    :ok
  end

  defp validate_manage_members_permission(scope, account_id) do
    if Authorization.authorize(:manage_members, scope, account_id),
      do: :ok,
      else: {:error, :not_authorized}
  end

  defp validate_user_not_already_member(email, account_id) do
    case Users.get_user_by_email(email) do
      nil ->
        :ok

      user ->
        if MembersRepository.user_has_account_access?(user.id, account_id),
          do: {:error, :user_already_member},
          else: :ok
    end
  end

  defp validate_no_pending_invitation(email, account_id) do
    if InvitationRepository.pending_invitation_exists?(email, account_id),
      do: {:error, :invitation_already_pending},
      else: :ok
  end

  defp create_invitation(scope, account_id, email, role) do
    attrs = %{
      email: email,
      role: role,
      account_id: account_id,
      invited_by_user_id: scope.user.id
    }

    InvitationRepository.create_invitation(scope, attrs)
  end

  defp send_invitation_email(invitation) do
    base = Application.get_env(:market_my_spec, :base_url, "http://localhost:4000")
    url = base <> "/invitations/accept/#{invitation.token}"

    case InvitationNotifier.deliver_invitation_email(invitation, url) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :email_delivery_failed}
    end
  end

  defp get_valid_invitation(token) do
    case InvitationRepository.get_by_token_hash(token) do
      nil ->
        {:error, :invalid_token}

      invitation ->
        cond do
          invitation.status != :pending -> {:error, :invalid_token}
          DateTime.compare(DateTime.utc_now(), invitation.expires_at) != :lt -> {:error, :expired_token}
          true -> {:ok, invitation}
        end
    end
  end

  defp resolve_or_create_user(invitation, %{email: provided_email} = user_attrs) do
    if provided_email == invitation.email do
      case Users.get_user_by_email(invitation.email) do
        nil -> Users.register_user(user_attrs)
        existing_user -> {:ok, existing_user}
      end
    else
      {:error, :email_mismatch}
    end
  end

  defp resolve_or_create_user(invitation, user_attrs) do
    user_attrs_with_email = Map.put(user_attrs, :email, invitation.email)

    case Users.get_user_by_email(invitation.email) do
      nil -> Users.register_user(user_attrs_with_email)
      existing_user -> {:ok, existing_user}
    end
  end

  defp accept_user_to_account(user, invitation) do
    inviter = Users.get_user!(invitation.invited_by_user_id)
    inviter_scope = %Scope{user: inviter, active_account_id: invitation.account_id}
    add_user_to_account(inviter_scope, user.id, invitation.account_id, invitation.role)
  end
end
