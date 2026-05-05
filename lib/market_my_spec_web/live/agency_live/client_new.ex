defmodule MarketMySpecWeb.AgencyLive.ClientNew do
  @moduledoc """
  LiveView for creating a new client account from the agency dashboard.

  The form creates a new individual Account and an originated AgencyClientGrant
  (originator="agency", status="accepted") in a single transaction.
  After successful creation, the user is redirected to /agency.
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        New Client Account
        <:subtitle>Create a client account for your agency to manage</:subtitle>
      </.header>

      <div class="mt-8">
        <.form
          for={@form}
          id="client-form"
          data-test="client-form"
          phx-change="validate"
          phx-submit="create-client"
        >
          <div class="space-y-4">
            <.input
              field={@form[:name]}
              type="text"
              label="Client Account Name"
              placeholder="Enter client name"
            />
            <.input
              field={@form[:slug]}
              type="text"
              label="Slug (optional)"
              placeholder="client-slug"
            />

            <div class="flex justify-end gap-2">
              <.button navigate={~p"/agency"} class="btn-ghost">
                Cancel
              </.button>
              <.button type="submit" phx-disable-with="Creating...">
                Create Client Account
              </.button>
            </div>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:form, to_form(client_changeset(%{}), as: :client))}
  end

  @impl true
  def handle_event("validate", %{"client" => client_params}, socket) do
    changeset = client_changeset(client_params)
    {:noreply, assign(socket, form: to_form(changeset, as: :client, action: :validate))}
  end

  def handle_event("create-client", %{"client" => client_params}, socket) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user
    agency_account = Accounts.get_user_agency_account(user)

    case agency_account do
      nil ->
        {:noreply, put_flash(socket, :error, "No agency account found")}

      agency ->
        client_attrs = %{name: client_params["name"], slug: client_params["slug"]}

        case Accounts.create_client_account_with_originated_grant(agency, client_attrs, user.id) do
          {:ok, _result} ->
            {:noreply,
             socket
             |> put_flash(:info, "Client account created successfully")
             |> push_navigate(to: ~p"/agency")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, form: to_form(changeset, as: :client))}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to create client account")}
        end
    end
  end

  defp client_changeset(params) do
    types = %{name: :string, slug: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:name])
    |> Ecto.Changeset.validate_length(:name, min: 1, max: 100)
  end
end
