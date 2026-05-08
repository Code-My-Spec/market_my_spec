defmodule MarketMySpecWeb.InvitationsLive.Accept do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users

  def render(assigns) do
    ~H"""
    <Layouts.marketing flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-lg">
        <div :if={@loading} class="text-center">
          <div class="loading loading-spinner loading-lg"></div>
          <p class="mt-4">Loading invitation...</p>
        </div>

        <div :if={@error} class="alert alert-error">
          <.icon name="hero-exclamation-circle" class="size-5" />
          <div>
            <h3 class="font-bold">
              <%= case @error do %>
                <% :invalid_token -> %>
                  Invalid Invitation
                <% :expired_token -> %>
                  Expired Invitation
                <% :already_accepted -> %>
                  Already Accepted
                <% _ -> %>
                  Error
              <% end %>
            </h3>
            <p class="text-sm">
              <%= case @error do %>
                <% :invalid_token -> %>
                  This invitation link is invalid or has been cancelled.
                <% :expired_token -> %>
                  This invitation has expired. Please request a new invitation.
                <% :already_accepted -> %>
                  This invitation has already been accepted.
                <% _ -> %>
                  Something went wrong. Please try again.
              <% end %>
            </p>
          </div>
        </div>

        <div :if={@invitation && !@error} class="space-y-6">
          <div class="card card-compact bg-base-100 shadow-lg">
            <div class="card-body">
              <h2 class="card-title text-center">
                <.icon name="hero-envelope" class="size-6 text-primary" /> You're Invited!
              </h2>

              <div class="space-y-4 text-center">
                <div>
                  <p class="text-sm text-base-content/70">
                    <strong>{@invitation.invited_by.email}</strong> invited you to join
                  </p>
                  <p class="text-lg font-semibold">
                    {@invitation.account.name}
                  </p>
                  <p class="text-sm text-base-content/70">
                    as a <span class="capitalize font-medium">{String.capitalize(to_string(@invitation.role))}</span>
                  </p>
                </div>

                <div class="divider"></div>

                <p class="text-sm text-base-content/70">To: {@invitation.email}</p>
              </div>
            </div>
          </div>

          <div :if={@existing_user} class="card card-compact bg-base-100 shadow-lg">
            <div class="card-body">
              <h3 class="card-title">Welcome back!</h3>
              <p class="text-sm text-base-content/70">
                You already have an account. Click below to accept the invitation.
              </p>
              <div class="card-actions justify-end">
                <.button
                  phx-click="accept_invitation"
                  phx-disable-with="Accepting..."
                  class="btn btn-primary w-full"
                >
                  Accept Invitation
                </.button>
              </div>
            </div>
          </div>

          <div :if={!@existing_user} class="card card-compact bg-base-100 shadow-lg">
            <div class="card-body">
              <h3 class="card-title">Create Your Account</h3>
              <p class="text-sm text-base-content/70">
                Complete your registration to accept the invitation.
              </p>
              <div class="space-y-4">
                <.input
                  name="email"
                  type="email"
                  label="Email"
                  readonly={true}
                  value={@invitation.email}
                />
                <div class="card-actions justify-end">
                  <.button
                    phx-click="accept_invitation"
                    phx-disable-with="Creating account..."
                    class="btn btn-primary w-full"
                  >
                    Create Account & Accept Invitation
                  </.button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.marketing>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_invitation_by_token(token) do
      nil ->
        {:ok, assign(socket, error: :invalid_token, loading: false, invitation: nil, existing_user: nil)}

      invitation ->
        cond do
          invitation.status == :accepted ->
            {:ok, assign(socket, error: :already_accepted, loading: false, invitation: nil, existing_user: nil)}

          invitation.status == :declined ->
            {:ok, assign(socket, error: :invalid_token, loading: false, invitation: nil, existing_user: nil)}

          DateTime.compare(DateTime.utc_now(), invitation.expires_at) != :lt ->
            {:ok, assign(socket, error: :expired_token, loading: false, invitation: nil, existing_user: nil)}

          true ->
            existing_user = Users.get_user_by_email(invitation.email)

            {:ok,
             socket
             |> assign(
               token: token,
               invitation: invitation,
               existing_user: existing_user,
               loading: false,
               error: nil
             )}
        end
    end
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: :invalid_token, loading: false, invitation: nil, existing_user: nil)}
  end

  def handle_event("accept_invitation", _params, socket) do
    user_attrs = %{email: socket.assigns.invitation.email}

    case Accounts.accept_invitation(socket.assigns.token, user_attrs) do
      {:ok, {user, _member}} ->
        if socket.assigns.existing_user do
          {:noreply,
           socket
           |> put_flash(:info, "Invitation accepted successfully!")
           |> push_navigate(to: ~p"/users/log-in")}
        else
          {:ok, _} =
            Users.deliver_login_instructions(user, &url(~p"/users/log-in/#{&1}"))

          {:noreply,
           socket
           |> put_flash(:info, "Account created! Check your email to confirm.")
           |> push_navigate(to: ~p"/users/log-in")}
        end

      {:error, :email_mismatch} ->
        {:noreply, put_flash(socket, :error, "Email address doesn't match the invitation.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to accept invitation. Please try again.")}
    end
  end
end
