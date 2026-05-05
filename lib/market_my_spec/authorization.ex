defmodule MarketMySpec.Authorization do
  @moduledoc """
  Policy module for checking and enforcing access control rules on accounts.
  """

  alias MarketMySpec.Accounts.AgencyClientGrantsRepository
  alias MarketMySpec.Accounts.MembersRepository
  alias MarketMySpec.Users.Scope

  def authorize(action, %Scope{} = scope, resource) do
    case {action, resource} do
      {:read_account, account_id} when is_binary(account_id) ->
        MembersRepository.user_has_account_access?(scope.user.id, account_id) ||
          AgencyClientGrantsRepository.user_has_agency_access_to_client?(scope.user.id, account_id)

      {:manage_account, account_id} when is_binary(account_id) ->
        user_role = MembersRepository.get_user_role(scope.user.id, account_id)
        user_role in [:owner, :admin]

      {:manage_members, account_id} when is_binary(account_id) ->
        user_role = MembersRepository.get_user_role(scope.user.id, account_id)
        user_role in [:owner, :admin]

      {:delete_account, account_id} when is_binary(account_id) ->
        user_role = MembersRepository.get_user_role(scope.user.id, account_id)
        user_role == :owner

      _ ->
        false
    end
  end

  def authorize!(action, scope, resource) do
    unless authorize(action, scope, resource) do
      raise "Unauthorized: #{action} on #{inspect(resource)}"
    end
  end

  @doc """
  Returns the access level for a given user on an account via agency grant.
  Returns nil if no agency grant exists.
  """
  @spec get_agency_access_level(Scope.t(), binary()) :: String.t() | nil
  def get_agency_access_level(%Scope{} = scope, account_id) do
    AgencyClientGrantsRepository.get_user_agency_access_level(scope.user.id, account_id)
  end
end
