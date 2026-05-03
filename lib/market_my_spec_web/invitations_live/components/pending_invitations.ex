defmodule MarketMySpecWeb.InvitationsLive.Components.PendingInvitations do
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
                  phx-click="cancel_invitation"
                  phx-value-invitation-id={invitation.id}
                  phx-target={@myself}
                  class="btn btn-error btn-sm"
                  data-confirm="Are you sure you want to cancel this invitation?"
                >
                  Cancel
                </button>
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
