defmodule MarketMySpecWeb.InvitationsLive.New do
  @moduledoc """
  LiveView for sending a new member invitation by email.

  Renders a form that allows account owners and admins to invite a new user
  by email address and role. Validates the email and role inputs, handles
  duplicate and already-member errors, and redirects back to the invitations
  list on success.
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Accounts.Invitation
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
        active_tab={:invitations}
      />

      <div class="mt-6">
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <h2 class="card-title">Invite Member</h2>

            <.form
              for={@form}
              id="invite-form"
              phx-change="validate"
              phx-submit="send_invitation"
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
                  phx-click="cancel"
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
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => account_id}, _session, socket) do
    current_scope = socket.assigns.current_scope

    case Accounts.get_account(current_scope, account_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Account not found")
         |> redirect(to: ~p"/accounts")}

      account ->
        if Authorization.authorize(:manage_members, current_scope, account.id) do
          {:ok,
           socket
           |> assign(:account, account)
           |> assign(:form, to_form(Invitation.changeset(%Invitation{}, %{})))}
        else
          {:ok,
           socket
           |> put_flash(:error, "You are not authorized to invite users")
           |> redirect(to: ~p"/accounts/#{account.id}/invitations")}
        end
    end
  end

  @impl true
  def handle_event("validate", %{"invitation" => invitation_params}, socket) do
    changeset = Invitation.changeset(%Invitation{}, invitation_params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("send_invitation", %{"invitation" => invitation_params}, socket) do
    case Accounts.invite_user(
           socket.assigns.current_scope,
           socket.assigns.account.id,
           invitation_params["email"],
           String.to_existing_atom(invitation_params["role"])
         ) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent successfully")
         |> push_navigate(to: ~p"/accounts/#{socket.assigns.account.id}/invitations")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, :user_already_member} ->
        changeset =
          %Invitation{}
          |> Invitation.changeset(invitation_params)
          |> Ecto.Changeset.add_error(:email, "User already has access to this account")

        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}

      {:error, :invitation_already_pending} ->
        changeset =
          %Invitation{}
          |> Invitation.changeset(invitation_params)
          |> Ecto.Changeset.add_error(:email, "An invitation is already pending for this email")

        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}

      {:error, :not_authorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to invite users")}

      {:error, :email_delivery_failed} ->
        {:noreply, put_flash(socket, :error, "Failed to send invitation email")}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/accounts/#{socket.assigns.account.id}/invitations")}
  end
end
