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

          <div :if={@mismatched_user} class="alert alert-warning">
            <.icon name="hero-exclamation-triangle" class="size-5" />
            <div>
              <h3 class="font-bold">Wrong account</h3>
              <p class="text-sm">
                You're signed in as <strong>{@current_scope.user.email}</strong>, but this invitation
                is for <strong>{@invitation.email}</strong>.
                <.link href={~p"/users/log-out"} method="delete" class="link link-primary">
                  Sign out
                </.link>
                and open the invitation link again to accept it.
              </p>
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
                  disabled={@mismatched_user}
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
                    disabled={@mismatched_user}
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
        {:ok, assign_blank(socket, :invalid_token)}

      invitation ->
        cond do
          invitation.status == :accepted ->
            {:ok, assign_blank(socket, :already_accepted)}

          invitation.status == :declined ->
            {:ok, assign_blank(socket, :invalid_token)}

          DateTime.compare(DateTime.utc_now(), invitation.expires_at) != :lt ->
            {:ok, assign_blank(socket, :expired_token)}

          true ->
            existing_user = Users.get_user_by_email(invitation.email)

            {:ok,
             socket
             |> assign(
               token: token,
               invitation: invitation,
               existing_user: existing_user,
               mismatched_user: mismatched_user?(socket.assigns[:current_scope], invitation),
               loading: false,
               error: nil
             )}
        end
    end
  end

  def mount(_params, _session, socket) do
    {:ok, assign_blank(socket, :invalid_token)}
  end

  def handle_event("accept_invitation", _params, socket) do
    if socket.assigns.mismatched_user do
      {:noreply,
       put_flash(
         socket,
         :error,
         "You're signed in as #{socket.assigns.current_scope.user.email}. Sign out and reopen the invitation link to accept."
       )}
    else
      do_accept_invitation(socket)
    end
  end

  defp do_accept_invitation(socket) do
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

  defp mismatched_user?(%{user: %{email: email}}, %{email: invitation_email})
       when is_binary(email) and is_binary(invitation_email) do
    email != invitation_email
  end

  defp mismatched_user?(_scope, _invitation), do: false

  defp assign_blank(socket, error) do
    assign(socket,
      error: error,
      loading: false,
      invitation: nil,
      existing_user: nil,
      mismatched_user: false
    )
  end
end
