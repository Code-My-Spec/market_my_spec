defmodule MarketMySpec.Accounts.InvitationNotifier do
  @moduledoc false

  import Swoosh.Email

  alias MarketMySpec.Mailer

  def deliver_invitation_email(invitation, url) do
    deliver(
      invitation.email,
      "You're invited to join #{invitation.account.name}",
      """
      Hi there,

      You've been invited to join #{invitation.account.name}.

      Click the link below to accept your invitation:
      #{url}

      This invitation will expire in 7 days.

      If you didn't expect this invitation, you can safely ignore this email.
      """
    )
  end

  def deliver_welcome_email(user, account) do
    deliver(
      user.email,
      "Welcome to #{account.name}!",
      """
      Hi #{user.email},

      Welcome to #{account.name}!

      You've successfully accepted your invitation and are now a member of the team.
      """
    )
  end

  def deliver_invitation_cancelled(invitation) do
    deliver(
      invitation.email,
      "Your invitation to #{invitation.account.name} has been cancelled",
      """
      Hi there,

      Your invitation to join #{invitation.account.name} has been cancelled.

      If you have any questions, please contact the account administrator.
      """
    )
  end

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"MarketMySpec", "noreply@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
