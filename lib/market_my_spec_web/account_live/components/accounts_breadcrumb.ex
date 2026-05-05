defmodule MarketMySpecWeb.AccountLive.Components.AccountsBreadcrumb do
  @moduledoc """
  HTML component for rendering an account breadcrumb navigation element.
  """

  use MarketMySpecWeb, :html

  @doc """
  Renders an account breadcrumb component.

  Shows the current account name with a link to switch accounts.
  Displays "Select Account" if no account is currently selected.

  ## Example

      <.account_breadcrumb scope={@scope} />

  """
  attr :scope, :map, required: true, doc: "Current user scope with active account"
  attr :current_path, :string, default: "/"

  def account_breadcrumb(assigns) do
    assigns =
      assign_new(assigns, :current_account, fn ->
        if assigns.scope.active_account_id do
          MarketMySpec.Accounts.get_account(assigns.scope, assigns.scope.active_account_id)
        else
          nil
        end
      end)

    ~H"""
    <div class="breadcrumbs text-sm">
      <ul>
        <li>
          <.link navigate={~p"/accounts/picker"}>
            <span :if={@current_account}>{@current_account.name}</span>
            <span :if={!@current_account}>Select Account</span>
          </.link>
        </li>
      </ul>
    </div>
    """
  end
end
