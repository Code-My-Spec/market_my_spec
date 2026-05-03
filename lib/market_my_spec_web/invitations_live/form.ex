defmodule MarketMySpecWeb.InvitationsLive.Form do
  use MarketMySpecWeb, :live_component
  import MarketMySpecWeb.CoreComponents

  def render(assigns) do
    ~H"""
    <div>
      <.button
        :if={!@show and @can_invite}
        phx-click="toggle_invite_form"
        phx-target={@myself}
        class="btn btn-success w-full"
      >
        <.icon name="hero-plus" class="size-4 mr-1" /> Invite Member
      </.button>

      <div :if={@show and @can_invite} class="card card-compact bg-base-200 p-4 mt-4">
        <.form
          for={@form}
          id="invite-form"
          phx-change="validate"
          phx-submit="send_invitation"
          phx-target={@myself}
        >
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              placeholder="Enter email address"
              required
            />
            <.input
              field={@form[:role]}
              type="select"
              label="Role"
              options={[
                {"Member", "member"},
                {"Admin", "admin"},
                {"Owner", "owner"}
              ]}
              required
            />
          </div>

          <div class="flex justify-end gap-2 mt-4">
            <.button
              type="button"
              phx-click="cancel_invite"
              phx-target={@myself}
              class="btn btn-secondary"
            >
              Cancel
            </.button>
            <.button type="submit" phx-disable-with="Sending..." class="btn btn-primary">
              Send Invitation
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end

  def handle_event("toggle_invite_form", _params, socket) do
    send(self(), {:show_invite_form, true})
    {:noreply, socket}
  end

  def handle_event("cancel_invite", _params, socket) do
    send(self(), {:cancel_invite_form})
    {:noreply, socket}
  end

  def handle_event("validate", %{"invitation" => invitation_params}, socket) do
    send(self(), {:validate_invitation, invitation_params})
    {:noreply, socket}
  end

  def handle_event("send_invitation", %{"invitation" => invitation_params}, socket) do
    send(self(), {:send_invitation, invitation_params})
    {:noreply, socket}
  end
end
