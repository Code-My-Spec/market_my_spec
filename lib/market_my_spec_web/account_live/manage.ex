defmodule MarketMySpecWeb.AccountLive.Manage do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Authorization
  alias MarketMySpecWeb.AccountLive.Components.Navigation

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.live_component
        module={Navigation}
        id="navigation"
        account={@account}
        current_scope={@current_scope}
        active_tab={:manage}
      />

      <div class="mt-6">
        <div class="space-y-6">
          <div class="card bg-base-100 border border-base-300">
            <div class="card-body">
              <h2 class="card-title">Account Details</h2>
              <.form
                for={@account_form}
                id="account-form"
                phx-change="validate-account"
                phx-submit="update-account"
              >
                <div class="space-y-4">
                  <.input
                    field={@account_form[:name]}
                    type="text"
                    label="Account Name"
                    placeholder="Enter account name"
                  />
                  <div class="flex justify-end gap-x-4">
                    <.button
                      phx-click="delete-account"
                      class="btn btn-error"
                      data-confirm="Are you sure you want to delete this account?"
                      disabled={!can_delete_account?(@current_scope, @account)}
                    >
                      Delete Account
                    </.button>
                    <.button type="submit" phx-disable-with="Updating...">
                      Update Account
                    </.button>
                  </div>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_scope = socket.assigns.current_scope

    case Accounts.get_account(current_scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Account not found")
         |> redirect(to: ~p"/accounts")}

      account ->
        Phoenix.PubSub.subscribe(MarketMySpec.PubSub, "account:#{account.id}")

        {:ok,
         socket
         |> assign(:account, account)
         |> assign(:account_form, to_form(Account.changeset(account, %{})))}
    end
  end

  @impl true
  def handle_event("validate-account", %{"account" => account_params}, socket) do
    changeset = Account.changeset(socket.assigns.account, account_params)
    {:noreply, assign(socket, :account_form, to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("update-account", %{"account" => account_params}, socket) do
    case Accounts.update_account(
           socket.assigns.current_scope,
           socket.assigns.account,
           account_params
         ) do
      {:ok, account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account updated successfully")
         |> assign(:account, account)
         |> assign(:account_form, to_form(Account.changeset(account, %{})))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :account_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete-account", _params, socket) do
    case Accounts.delete_account(socket.assigns.current_scope, socket.assigns.account) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account deleted successfully")
         |> redirect(to: ~p"/accounts")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete account")}
    end
  end

  @impl true
  def handle_info({:account_updated, account}, socket) do
    {:noreply, assign(socket, :account, account)}
  end

  defp can_delete_account?(current_scope, account) do
    Authorization.authorize(:delete_account, current_scope, account.id)
  end
end
