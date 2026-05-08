defmodule MarketMySpecWeb.AgencyLive.Dashboard do
  @moduledoc """
  Agency client management dashboard. Lists all client accounts the agency manages,
  showing each client's name and access level. Supports entering client accounts
  and revoking invited grants.

  Only accessible to users with an agency-typed account (enforced via on_mount guard).
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Agencies

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Client Dashboard
        <:subtitle>Accounts your agency manages</:subtitle>
      </.header>

      <div data-test="agency-client-dashboard" class="mt-8">
        <div :if={@grants == []} class="text-center py-12 text-base-content/60">
          <p class="font-mono text-sm">No client accounts yet.</p>
          <.button navigate={~p"/agency/clients/new"} class="btn-primary mt-4">
            Add Client Account
          </.button>
        </div>

        <div :if={@grants != []}>
          <div class="flex justify-end mb-4">
            <.button navigate={~p"/agency/clients/new"} class="btn-primary btn-sm">
              Add Client Account
            </.button>
          </div>

          <div class="overflow-x-auto rounded-box border border-base-300">
            <table class="table">
              <thead class="bg-base-200">
                <tr>
                  <th class="font-mono text-xs uppercase tracking-wider">Client Account</th>
                  <th class="font-mono text-xs uppercase tracking-wider">Access Level</th>
                  <th class="font-mono text-xs uppercase tracking-wider text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={grant <- @grants}
                  data-test="client-row"
                  data-client-id={grant.client_account.id}
                  data-client-name={grant.client_account.name}
                >
                  <td data-test="client-name" class="font-medium">
                    {grant.client_account.name}
                  </td>
                  <td data-test="access-level">
                    <span class="badge badge-outline font-mono text-xs">
                      {format_access_level(grant.access_level)}
                    </span>
                  </td>
                  <td class="text-right">
                    <div :if={grant.originator == "agency"} data-test="client-row-originator" class="inline-flex gap-2 items-center">
                      <.button
                        phx-click="enter_client"
                        phx-value-account-id={grant.client_account.id}
                        data-test="enter-client"
                        class="btn-sm"
                      >
                        Enter
                      </.button>
                    </div>
                    <div
                      :if={grant.originator == "client"}
                      data-test="client-row-invited"
                      data-access-level={grant.access_level}
                      data-client-id={grant.client_account.id}
                      class="inline-flex gap-2 items-center"
                    >
                      <.button
                        phx-click="enter_client"
                        phx-value-account-id={grant.client_account.id}
                        data-test="enter-client"
                        class="btn-sm"
                      >
                        Enter
                      </.button>
                      <button
                        type="button"
                        class="btn btn-sm btn-error btn-outline"
                        onclick={"document.getElementById('revoke-grant-modal-#{grant.id}').showModal()"}
                        data-test="revoke-grant"
                      >
                        Revoke
                      </button>
                      <.confirm_modal
                        id={"revoke-grant-modal-#{grant.id}"}
                        title="Revoke agency access?"
                        body="This will revoke your agency's access to this client account. You would need a new invitation to regain access."
                        confirm_label="Revoke"
                        confirm_event="revoke_grant"
                        confirm_value={%{"grant-id": grant.id}}
                      />
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope
    user = current_scope.user
    agency_account = Accounts.get_user_agency_account(user)

    grants =
      case agency_account do
        nil -> []
        agency -> Agencies.list_grants_for_agency(agency.id)
      end

    {:ok,
     socket
     |> assign(:agency_account, agency_account)
     |> assign(:grants, grants)}
  end

  @impl true
  def handle_event("enter_client", %{"account-id" => account_id}, socket) do
    user = socket.assigns.current_scope.user

    if Agencies.user_has_agency_access_to_client?(user, account_id) do
      case Accounts.set_active_client_context(user, account_id) do
        {:ok, _user} ->
          {:noreply, push_navigate(socket, to: ~p"/accounts")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to switch client context")}
      end
    else
      {:noreply, put_flash(socket, :error, "You do not have access to this client account")}
    end
  end

  def handle_event("revoke_grant", %{"grant-id" => grant_id}, socket) do
    case Agencies.revoke_grant(grant_id) do
      {:ok, _grant} ->
        user = socket.assigns.current_scope.user
        agency_account = Accounts.get_user_agency_account(user)

        grants =
          case agency_account do
            nil -> []
            agency -> Agencies.list_grants_for_agency(agency.id)
          end

        {:noreply,
         socket
         |> put_flash(:info, "Access revoked successfully")
         |> assign(:grants, grants)}

      {:error, :not_revokable} ->
        {:noreply, put_flash(socket, :error, "Originated grants cannot be revoked")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke access")}
    end
  end

  defp format_access_level("read_only"), do: "Read Only"
  defp format_access_level("account_manager"), do: "Account Manager"
  defp format_access_level("admin"), do: "Admin"
  defp format_access_level(other), do: other |> to_string() |> String.capitalize()
end
