defmodule MarketMySpec.Accounts.InvitationRepository do
  @moduledoc false

  import Ecto.Query, warn: false

  alias MarketMySpec.Accounts.Invitation
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope

  def create_invitation(%Scope{} = _scope, attrs) do
    invitation = %Invitation{}
    {encoded_token, token_changeset} = Invitation.build_token(invitation)

    changeset =
      token_changeset
      |> Invitation.changeset(attrs)
      |> Ecto.Changeset.put_change(:expires_at, default_expiry())

    case Repo.insert(changeset) do
      {:ok, invitation} ->
        invitation = %{invitation | token: encoded_token}
        {:ok, Repo.preload(invitation, [:account, :invited_by])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def get_invitation(%Scope{} = _scope, id) do
    from(i in Invitation, preload: [:account, :invited_by])
    |> Repo.get(id)
  end

  def get_by_token_hash(encoded_token) do
    hash = Invitation.token_hash(encoded_token)

    from(i in Invitation,
      where: i.token_hash == ^hash,
      preload: [:account, :invited_by]
    )
    |> Repo.one()
  end

  def list_pending_invitations(%Scope{} = _scope, account_id) when not is_nil(account_id) do
    now = DateTime.utc_now()

    from(i in Invitation,
      where: i.account_id == ^account_id,
      where: i.status == :pending,
      where: i.expires_at > ^now,
      preload: [:invited_by],
      order_by: [desc: i.inserted_at]
    )
    |> Repo.all()
  end

  def list_pending_invitations(_scope, nil), do: []

  def pending_invitation_exists?(email, account_id) do
    now = DateTime.utc_now()

    Repo.exists?(
      from i in Invitation,
        where:
          i.email == ^email and
            i.account_id == ^account_id and
            i.status == :pending and
            i.expires_at > ^now
    )
  end

  def accept(%Scope{} = _scope, %Invitation{} = invitation) do
    invitation
    |> Invitation.accept_changeset()
    |> Repo.update()
  end

  def cancel(%Scope{} = _scope, %Invitation{} = invitation) do
    invitation
    |> Invitation.decline_changeset()
    |> Repo.update()
  end

  def list_user_invitations(email) when is_binary(email) do
    now = DateTime.utc_now()

    from(i in Invitation,
      where: i.email == ^email,
      where: i.status == :pending,
      where: i.expires_at > ^now,
      preload: [:account]
    )
    |> Repo.all()
  end

  def cleanup_expired_invitations(days_old) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_old, :day)

    from(i in Invitation,
      where: i.expires_at <= ^cutoff_date,
      where: i.status == :pending
    )
    |> Repo.delete_all()
  end

  defp default_expiry do
    DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)
  end
end
