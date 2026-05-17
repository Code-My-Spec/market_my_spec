defmodule MarketMySpec.McpServers.Validators do
  @moduledoc """
  Shared scope validation for MCP tool handlers.

  Tools call `validate_scope/1` at the top of `execute/2` to confirm the
  MCP transport authenticated a request that carries a usable
  `MarketMySpec.Users.Scope` with an `active_account` loaded. Returning
  the scope keeps each tool focused on its own business logic instead of
  repeating the same shape-check.
  """

  alias MarketMySpec.Users.Scope

  @doc """
  Returns `{:ok, scope}` when `frame.assigns.current_scope` is a `Scope`
  with both `active_account_id` and an `active_account` struct populated.

  Errors out with `{:error, :missing_active_account}` otherwise. Tools
  surface the error as a tool-level `Response.error/2` so callers see why
  the request was rejected rather than a transport-level failure.
  """
  @spec validate_scope(map()) ::
          {:ok, Scope.t()} | {:error, :missing_active_account}
  def validate_scope(frame) do
    case frame.assigns[:current_scope] do
      %Scope{active_account: %{id: _}, active_account_id: id} = scope when not is_nil(id) ->
        {:ok, scope}

      _ ->
        {:error, :missing_active_account}
    end
  end
end
