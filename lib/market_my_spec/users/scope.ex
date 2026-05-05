defmodule MarketMySpec.Users.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `MarketMySpec.Users.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias MarketMySpec.Accounts.MembersRepository
  alias MarketMySpec.Users.User

  defstruct user: nil,
            active_account: nil,
            active_account_id: nil

  @doc """
  Creates a scope for the given user.

  Populates `active_account_id` with the user's first account membership
  (ordered by creation time, newest first) so that Files context calls and
  MCP tool executions have a non-nil account context without requiring
  an explicit account-picker step.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    active_account_id =
      case MembersRepository.list_user_accounts(user.id) do
        [account | _] -> account.id
        [] -> nil
      end

    %__MODULE__{user: user, active_account_id: active_account_id}
  end

  def for_user(nil), do: nil
end
