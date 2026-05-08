defmodule MarketMySpecWeb.AccountLive.Picker do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Accounts.MembersRepository

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center min-h-screen px-4">
      <div class="w-full max-w-md">
        <.header>
          Select Account
          <:subtitle>Choose which account you'd like to work with</:subtitle>
        </.header>

        <div class="mt-8" data-test="account-picker">
          <ul class="menu bg-base-200 rounded-box w-full">
            <li
              :for={account <- @accounts}
              class={if account.id == @current_account_id, do: "bordered", else: ""}
            >
              <a
                data-test={"account-picker-item-#{account.slug}"}
                phx-click="account-selected"
                phx-value-account-id={account.id}
                class={if account.id == @current_account_id, do: "active", else: ""}
              >
                <div class="flex-1">
                  <div class="font-semibold">{account.name}</div>
                  <div :if={@user_roles[account.id]} class="text-sm opacity-70">
                    {String.capitalize(to_string(@user_roles[account.id]))}
                  </div>
                </div>
                <div :if={account.id == @current_account_id} class="badge badge-primary">
                  Current
                </div>
              </a>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope
    accounts = Accounts.list_accounts(current_scope)
    current_account_id = Map.get(current_scope, :active_account_id)

    user_roles =
      Enum.into(accounts, %{}, fn account ->
        {account.id, get_user_role(account.id, current_scope.user.id)}
      end)

    {:ok,
     socket
     |> assign(:accounts, accounts)
     |> assign(:current_account_id, current_account_id)
     |> assign(:user_roles, user_roles)}
  end

  @impl true
  def handle_event("account-selected", %{"account-id" => account_id}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.set_active_account_context(user, account_id) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account selected")
         |> push_navigate(to: ~p"/files")}

      {:error, :not_a_member} ->
        {:noreply, put_flash(socket, :error, "You don't have access to this account")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not switch accounts")}
    end
  end

  defp get_user_role(account_id, user_id) do
    case MembersRepository.get_user_role(user_id, account_id) do
      nil -> :member
      role -> role
    end
  end
end
