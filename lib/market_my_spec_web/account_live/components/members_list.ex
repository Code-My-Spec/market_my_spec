defmodule MarketMySpecWeb.AccountLive.Components.MembersList do
  use MarketMySpecWeb, :live_component
  import MarketMySpecWeb.CoreComponents

  def render(assigns) do
    ~H"""
    <div>
      <.table :if={@members != []} id="members-table" rows={@members}>
        <:col :let={member} label="User">
          <div class="flex items-center gap-3">
            <div class="avatar placeholder">
              <div class="bg-neutral text-neutral-content rounded-full w-8">
                <span class="text-xs">
                  {String.first(member.user.email)}
                </span>
              </div>
            </div>
            <div>
              <div class="font-bold">{member.user.email}</div>
            </div>
          </div>
        </:col>
        <:col :let={member} label="Role">
          <div :if={@editing_member_id != member.id}>
            <.button
              :if={@can_manage and member.user.id != @current_user.id}
              phx-click="edit-member-role"
              phx-value-member-id={member.id}
              phx-target={@myself}
              class="btn-sm btn-ghost"
            >
              <span class="badge badge-outline">
                {member.role |> Atom.to_string() |> String.capitalize()}
              </span>
              <.icon name="hero-chevron-down" class="size-3 ml-1" />
            </.button>
            <span :if={!@can_manage or member.user.id == @current_user.id} class="badge badge-outline">
              {member.role |> Atom.to_string() |> String.capitalize()}
            </span>
          </div>

          <div :if={@editing_member_id == member.id} class="flex gap-2 items-center">
            <select
              phx-change="update-member-role"
              phx-value-member-id={member.id}
              phx-target={@myself}
              class="select select-xs select-bordered"
            >
              <option value="member" selected={member.role == "member"}>
                Member
              </option>
              <option value="admin" selected={member.role == "admin"}>Admin</option>
              <option value="owner" selected={member.role == "owner"}>Owner</option>
            </select>
            <.button phx-click="cancel-edit-role" phx-target={@myself} class="btn-xs btn-ghost">
              <.icon name="hero-x-mark" class="size-3" />
            </.button>
          </div>
        </:col>
        <:col :let={member} label="Joined">
          {Calendar.strftime(member.inserted_at, "%B %d, %Y")}
        </:col>
        <:action :let={member} :if={@can_manage}>
          <div :if={member.user.id != @current_user.id}>
            <.button
              :if={@removing_member_id != member.id}
              phx-click="confirm-remove-member"
              phx-value-member-id={member.id}
              phx-target={@myself}
              class="btn-sm btn-ghost text-error"
            >
              Remove
            </.button>

            <div :if={@removing_member_id == member.id} class="flex gap-1">
              <.button
                phx-click="remove-member"
                phx-value-member-id={member.id}
                phx-target={@myself}
                class="btn-xs btn-error"
              >
                Confirm
              </.button>
              <.button phx-click="cancel-remove-member" phx-target={@myself} class="btn-xs btn-ghost">
                Cancel
              </.button>
            </div>
          </div>
        </:action>
      </.table>

      <div :if={@members == []} class="text-center py-8">
        <p class="text-base-content/70">No members found</p>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     socket
     |> assign(:editing_member_id, nil)
     |> assign(:removing_member_id, nil)}
  end

  def handle_event("edit-member-role", %{"member-id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    {:noreply, assign(socket, :editing_member_id, member_id)}
  end

  def handle_event("cancel-edit-role", _params, socket) do
    {:noreply, assign(socket, :editing_member_id, nil)}
  end

  def handle_event("update-member-role", %{"member-id" => member_id, "value" => role}, socket) do
    member_id = String.to_integer(member_id)
    send(self(), {:update_member_role, member_id, role})
    {:noreply, assign(socket, :editing_member_id, nil)}
  end

  def handle_event("update-member-role", %{"value" => role}, socket) do
    member_id = socket.assigns.editing_member_id
    send(self(), {:update_member_role, member_id, role})
    {:noreply, assign(socket, :editing_member_id, nil)}
  end

  def handle_event("confirm-remove-member", %{"member-id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    {:noreply, assign(socket, :removing_member_id, member_id)}
  end

  def handle_event("cancel-remove-member", _params, socket) do
    {:noreply, assign(socket, :removing_member_id, nil)}
  end

  def handle_event("remove-member", %{"member-id" => member_id}, socket) do
    member_id = String.to_integer(member_id)
    send(self(), {:remove_member, member_id})
    {:noreply, assign(socket, :removing_member_id, nil)}
  end
end
