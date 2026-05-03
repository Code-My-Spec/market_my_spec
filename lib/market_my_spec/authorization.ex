defmodule MarketMySpec.Authorization do
  alias MarketMySpec.Accounts.MembersRepository
  alias MarketMySpec.Users.Scope

  def authorize(action, %Scope{} = scope, resource) do
    case {action, resource} do
      {:read_account, account_id} when is_binary(account_id) ->
        MembersRepository.user_has_account_access?(scope.user.id, account_id)

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
end
