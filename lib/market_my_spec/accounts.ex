defmodule MarketMySpec.Accounts do
  alias MarketMySpec.Accounts.{Account, AccountsRepository, MembersRepository}
  alias MarketMySpec.Accounts.{InvitationRepository, InvitationNotifier}
  alias MarketMySpec.Authorization
  alias MarketMySpec.Users
  alias MarketMySpec.Users.Scope

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

  def list_accounts(%Scope{} = scope) do
    MembersRepository.list_user_accounts(scope.user.id)
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
