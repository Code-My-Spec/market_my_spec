defmodule MarketMySpecWeb.InvitationsLive.Components.PendingInvitations do
  @moduledoc """
  LiveComponent that renders the list of pending invitations for an account.
  """

  use MarketMySpecWeb, :live_component
  import MarketMySpecWeb.CoreComponents

  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= if Enum.empty?(@invitations) do %>
        <div class="text-center py-8">
          <div class="text-gray-500 text-sm">No pending invitations</div>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <.table id="pending-invitations" rows={@invitations}>
            <:col :let={invitation} label="Email">
              {invitation.email}
            </:col>
            <:col :let={invitation} label="Role">
              <span class="capitalize">{invitation.role}</span>
            </:col>
            <:col :let={invitation} label="Invited By">
              {invitation.invited_by.email}
            </:col>
            <:col :let={invitation} label="Date Sent">
              {Calendar.strftime(invitation.inserted_at, "%b %d, %Y")}
            </:col>
            <:col :let={invitation} label="Expires At">
              <span class={[expired?(invitation) && "text-warning font-semibold"]}>
                {Calendar.strftime(invitation.expires_at, "%b %d, %Y")}
              </span>
            </:col>
            <:action :let={invitation}>
              <%= if @can_manage and not expired?(invitation) do %>
                <button
                  type="button"
                  class="btn btn-error btn-sm"
                  onclick={"document.getElementById('cancel-invitation-modal-#{invitation.id}').showModal()"}
                  data-test={"open-cancel-invitation-modal-#{invitation.id}"}
                >
                  Cancel
                </button>
                <.confirm_modal
                  id={"cancel-invitation-modal-#{invitation.id}"}
                  title="Cancel invitation?"
                  body="This will cancel the invitation. The recipient will no longer be able to use this invite link."
                  confirm_label="Cancel Invitation"
                  confirm_event="cancel_invitation"
                  confirm_value={%{"invitation-id": invitation.id}}
                  phx_target={@myself}
                />
              <% end %>
            </:action>
          </.table>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("cancel_invitation", %{"invitation-id" => invitation_id}, socket) do
    send(self(), {:cancel_invitation, String.to_integer(invitation_id)})
    {:noreply, socket}
  end

  defp expired?(invitation) do
    DateTime.compare(invitation.expires_at, DateTime.utc_now()) == :lt
  end
end
