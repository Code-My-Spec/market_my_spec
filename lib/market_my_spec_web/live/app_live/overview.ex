defmodule MarketMySpecWeb.AppLive.Overview do
  @moduledoc """
  Post-sign-in landing page. Forces account creation when the user has
  zero accounts (the previous redirect-to-/accounts/new dumped users
  on a bare CRUD form with no context). When the user has at least one
  account, shows a small overview with quick links into the product.

  Pattern mirrors code_my_spec's AppLive.Overview onboarding step: zero
  accounts → friendly inline form; one or more → product landing.
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Accounts.Account

  @impl true
  def mount(_params, _session, socket) do
    accounts = Accounts.list_accounts(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Welcome")
     |> assign(:accounts, accounts)
     |> assign(:form, to_form(Account.create_changeset(%{})))}
  end

  @impl true
  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset =
      account_params
      |> Map.delete("type")
      |> Account.create_changeset()
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"account" => account_params}, socket) do
    # Strip :type — self-service accounts are always :individual
    # (agency accounts are admin-provisioned only).
    safe_params = Map.delete(account_params, "type")

    case Accounts.create_account(socket.assigns.current_scope, safe_params) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workspace created.")
         |> push_navigate(to: ~p"/app")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl py-10">
        <%= if @accounts == [] do %>
          <.zero_account_form form={@form} />
        <% else %>
          <.welcome accounts={@accounts} current_scope={@current_scope} />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :form, :map, required: true

  defp zero_account_form(assigns) do
    ~H"""
    <div class="space-y-6" data-test="onboarding-create-account">
      <header>
        <h1 class="text-2xl font-semibold">Welcome to MarketMySpec.</h1>
        <p class="mt-2 text-base-content/70">
          One quick step before you get started: create a workspace. It's where your saved
          searches, threads, touchpoints, and Problem-Discovery frames live. You can rename or
          add more later.
        </p>
      </header>

      <.form
        for={@form}
        id="onboarding-account-form"
        data-test="onboarding-account-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-4"
      >
        <.input
          field={@form[:name]}
          type="text"
          label="Workspace name"
          placeholder="My Co"
          autofocus
        />
        <.input
          field={@form[:slug]}
          type="text"
          label="URL slug"
          placeholder="my-co"
        />
        <footer class="pt-2">
          <.button phx-disable-with="Creating...">Create workspace</.button>
        </footer>
      </.form>
    </div>
    """
  end

  attr :accounts, :list, required: true
  attr :current_scope, :map, required: true

  defp welcome(assigns) do
    ~H"""
    <div class="space-y-8" data-test="onboarding-welcome">
      <header>
        <h1 class="text-2xl font-semibold">Welcome back.</h1>
        <p :if={@current_scope.active_account} class="mt-1 text-sm text-base-content/60">
          Active workspace: <span class="font-medium">{@current_scope.active_account.name}</span>
        </p>
      </header>

      <section>
        <h2 class="text-sm font-medium text-base-content/70 uppercase tracking-wide">Jump in</h2>
        <ul class="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-3">
          <li :if={@current_scope.active_account_id}>
            <.link
              navigate={~p"/app/problem-discovery/frames"}
              class="block rounded border border-base-300 p-4 hover:bg-base-200"
            >
              <div class="font-medium">Problem discovery</div>
              <div class="text-xs text-base-content/60 mt-1">
                Frame a hypothesis and run the 5-stage discovery pipeline.
              </div>
            </.link>
          </li>
          <li :if={@current_scope.active_account_id}>
            <.link
              navigate={~p"/app/accounts/#{@current_scope.active_account_id}/searches"}
              class="block rounded border border-base-300 p-4 hover:bg-base-200"
            >
              <div class="font-medium">Saved searches</div>
              <div class="text-xs text-base-content/60 mt-1">
                Manage Reddit/ElixirForum saved searches that feed touchpoints.
              </div>
            </.link>
          </li>
          <li>
            <.link
              navigate={~p"/app/chat"}
              class="block rounded border border-base-300 p-4 hover:bg-base-200"
            >
              <div class="font-medium">Chat</div>
              <div class="text-xs text-base-content/60 mt-1">
                Streaming LLM chat with MCP tool access.
              </div>
            </.link>
          </li>
          <li>
            <.link
              navigate={~p"/app/integrations"}
              class="block rounded border border-base-300 p-4 hover:bg-base-200"
            >
              <div class="font-medium">Integrations</div>
              <div class="text-xs text-base-content/60 mt-1">
                Connect Google Analytics, GitHub, and other providers.
              </div>
            </.link>
          </li>
        </ul>
      </section>

      <section>
        <h2 class="text-sm font-medium text-base-content/70 uppercase tracking-wide">Workspaces</h2>
        <ul class="mt-3 space-y-2">
          <li :for={a <- @accounts}>
            <.link
              navigate={~p"/app/accounts/#{a.id}"}
              class="block rounded border border-base-300 px-4 py-2 hover:bg-base-200"
            >
              <span class="font-medium">{a.name}</span>
              <span class="text-xs text-base-content/60 ml-2">{a.slug}</span>
            </.link>
          </li>
          <li>
            <.link navigate={~p"/app/accounts/new"} class="text-xs link link-hover">
              + Create another workspace
            </.link>
          </li>
        </ul>
      </section>
    </div>
    """
  end
end
