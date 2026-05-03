defmodule MarketMySpecWeb.AccountLive.Members do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
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
        active_tab={:members}
      />

      <div class="mt-6">
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <h2 class="card-title">Members</h2>

            <div :if={@members == []} class="text-center py-8">
              <p class="text-base-content/70">No members found</p>
            </div>

            <div :if={@members != []} class="overflow-x-auto">
              <table class="table">
                <thead>
                  <tr>
                    <th>Email</th>
                    <th>Role</th>
                    <th>Joined</th>
                    <th :if={can_manage_members?(@current_scope, @account)}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={member <- @members}>
                    <td class="text-base-content/70">{member.user.email}</td>
                    <td>
                      <div :if={
                        can_manage_members?(@current_scope, @account) and
                          member.user.id != @current_scope.user.id
                      }>
                        <.form
                          for={%{}}
                          phx-change="update-member-role"
                          phx-value-member-id={member.id}
                        >
                          <select name="role" class="select select-sm select-bordered">
                            <option value="member" selected={member.role == :member}>Member</option>
                            <option value="admin" selected={member.role == :admin}>Admin</option>
                            <option value="owner" selected={member.role == :owner}>Owner</option>
                          </select>
                        </.form>
                      </div>
                      <div :if={
                        !can_manage_members?(@current_scope, @account) or
                          member.user.id == @current_scope.user.id
                      }>
                        <span class="badge badge-outline">
                          {String.capitalize(to_string(member.role))}
                        </span>
                      </div>
                    </td>
                    <td class="text-base-content/70">
                      {Calendar.strftime(member.inserted_at, "%B %d, %Y")}
                    </td>
                    <td :if={can_manage_members?(@current_scope, @account)}>
                      <.button
                        :if={member.user.id != @current_scope.user.id}
                        phx-click="remove-member"
                        phx-value-member-id={member.id}
                        class="btn btn-sm btn-error"
                        data-confirm="Are you sure you want to remove this member?"
                      >
                        Remove
                      </.button>
                    </td>
                  </tr>
                </tbody>
              </table>
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
        members = Accounts.list_account_members(current_scope, account.id)

        Phoenix.PubSub.subscribe(MarketMySpec.PubSub, "account:#{account.id}")
        Phoenix.PubSub.subscribe(MarketMySpec.PubSub, "account_members:#{account.id}")

        {:ok,
         socket
         |> assign(:account, account)
         |> assign(:members, members)}
    end
  end

  @impl true
  def handle_event("remove-member", %{"member-id" => member_id}, socket) do
    account = socket.assigns.account
    member = Enum.find(socket.assigns.members, &(&1.id == String.to_integer(member_id)))

    case member do
      nil ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      member ->
        case Accounts.remove_user_from_account(
               socket.assigns.current_scope,
               member.user_id,
               account.id
             ) do
          {:ok, _member} ->
            members = Accounts.list_account_members(socket.assigns.current_scope, account.id)

            {:noreply,
             socket
             |> put_flash(:info, "Member removed successfully")
             |> assign(:members, members)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to remove member")}
        end
    end
  end

  def handle_event("update-member-role", %{"member-id" => member_id, "role" => role}, socket) do
    account = socket.assigns.account
    member = Enum.find(socket.assigns.members, &(&1.id == String.to_integer(member_id)))

    case member do
      nil ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      member ->
        case Accounts.update_user_role(
               socket.assigns.current_scope,
               member.user_id,
               account.id,
               String.to_existing_atom(role)
             ) do
          {:ok, _member} ->
            members = Accounts.list_account_members(socket.assigns.current_scope, account.id)

            {:noreply,
             socket
             |> put_flash(:info, "Member role updated successfully")
             |> assign(:members, members)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to update member role")}
        end
    end
  end

  @impl true
  def handle_info({:account_updated, account}, socket) do
    {:noreply, assign(socket, :account, account)}
  end

  def handle_info({:member_added, _member}, socket) do
    members =
      Accounts.list_account_members(socket.assigns.current_scope, socket.assigns.account.id)

    {:noreply, assign(socket, :members, members)}
  end

  def handle_info({:member_removed, _member}, socket) do
    members =
      Accounts.list_account_members(socket.assigns.current_scope, socket.assigns.account.id)

    {:noreply, assign(socket, :members, members)}
  end

  def handle_info({:member_role_updated, _member}, socket) do
    members =
      Accounts.list_account_members(socket.assigns.current_scope, socket.assigns.account.id)

    {:noreply, assign(socket, :members, members)}
  end

  defp can_manage_members?(current_scope, account) do
    Authorization.authorize(:manage_members, current_scope, account.id)
  end
end
