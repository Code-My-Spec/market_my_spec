defmodule MarketMySpecWeb.AccountLive.Index do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Accounts.Account

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Your Accounts
        <:subtitle>Manage your accounts</:subtitle>
      </.header>

      <div class="mt-8 space-y-6">
        <div :if={Enum.any?(@accounts)} class="space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div
              :for={account <- @accounts}
              class="card bg-base-100 border border-base-300"
            >
              <div class="card-body">
                <h2 class="card-title text-base">{account.name}</h2>
                <p class="text-sm text-base-content/70">
                  {account.slug}
                </p>
                <div class="card-actions justify-end mt-4">
                  <.button navigate={~p"/accounts/#{account}/members"} class="btn-sm btn-ghost">
                    Members
                  </.button>
                  <.button navigate={~p"/accounts/#{account}"} class="btn-sm">
                    Manage
                  </.button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={Enum.empty?(@accounts) && !@show_create_form} class="text-center py-12">
          <p class="text-base-content/70 mb-4">You don't have any accounts yet.</p>
        </div>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <div :if={!@show_create_form} class="text-center">
              <h3 class="text-lg font-semibold mb-2">Create Account</h3>
              <p class="text-sm text-base-content/70 mb-4">
                Create an account to start collaborating
              </p>
              <.button phx-click="show-create-form">
                <.icon name="hero-plus" class="size-4 mr-2" /> Create Account
              </.button>
            </div>

            <div :if={@show_create_form} class="space-y-4">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-semibold">Create Account</h3>
                <button phx-click="show-create-form" class="btn btn-sm btn-ghost">
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </div>

              <.form
                for={@form}
                id="create-account-form"
                phx-change="validate"
                phx-submit="create-account"
              >
                <div class="space-y-4">
                  <.input
                    field={@form[:name]}
                    type="text"
                    label="Account Name"
                    placeholder="Enter account name"
                  />
                  <.input field={@form[:slug]} type="text" label="Slug" placeholder="account-slug" />

                  <div class="flex justify-end space-x-2">
                    <.button type="button" phx-click="show-create-form" class="btn-ghost">
                      Cancel
                    </.button>
                    <.button type="submit" phx-disable-with="Creating...">
                      Create Account
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
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope
    accounts = Accounts.list_accounts(current_scope)

    # Subscribe to account updates
    Phoenix.PubSub.subscribe(MarketMySpec.PubSub, "accounts:#{current_scope.user.id}")

    {:ok,
     socket
     |> assign(:accounts, accounts)
     |> assign(:show_create_form, false)
     |> assign(:form, to_form(Account.create_changeset(%{})))}
  end

  @impl true
  def handle_event("show-create-form", _params, socket) do
    {:noreply, assign(socket, :show_create_form, !socket.assigns.show_create_form)}
  end

  def handle_event("create-account", %{"account" => account_params}, socket) do
    case Accounts.create_account(socket.assigns.current_scope, account_params) do
      {:ok, _account} ->
        accounts = Accounts.list_accounts(socket.assigns.current_scope)

        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully")
         |> assign(:accounts, accounts)
         |> assign(:show_create_form, false)
         |> assign(:form, to_form(Account.create_changeset(%{})))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset = Account.create_changeset(account_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_info({:account_updated, _account}, socket) do
    accounts = Accounts.list_accounts(socket.assigns.current_scope)
    {:noreply, assign(socket, :accounts, accounts)}
  end

  def handle_info({:account_created, _account}, socket) do
    accounts = Accounts.list_accounts(socket.assigns.current_scope)
    {:noreply, assign(socket, :accounts, accounts)}
  end
end
