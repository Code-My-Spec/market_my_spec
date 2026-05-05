defmodule MarketMySpec.Accounts.MembersRepository do
  @moduledoc """
  Repository for account membership queries and mutations.
  """

  import Ecto.Query, warn: false

  alias MarketMySpec.Accounts.{Account, Member}
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.User

  def add_user_to_account(user_id, account_id, role \\ :member) do
    %Member{}
    |> Member.changeset(%{user_id: user_id, account_id: account_id, role: role})
    |> Repo.insert()
  end

  def remove_user_from_account(user_id, account_id) do
    case Repo.get_by(Member, user_id: user_id, account_id: account_id) do
      nil -> {:error, :not_found}
      member -> delete_member(member, account_id)
    end
  end

  defp delete_member(%{role: :owner} = member, account_id) do
    if count_owners(account_id) > 1 do
      Repo.delete(member)
    else
      {:error, :last_owner}
    end
  end

  defp delete_member(member, _account_id), do: Repo.delete(member)

  def update_user_role(user_id, account_id, role) do
    case Repo.get_by(Member, user_id: user_id, account_id: account_id) do
      nil ->
        {:error, :not_found}

      member ->
        changeset = Member.update_role_changeset(member, %{role: role})
        validated_changeset = Member.validate_owner_exists(changeset, Repo)

        case validated_changeset.valid? do
          true -> Repo.update(validated_changeset)
          false -> {:error, validated_changeset}
        end
    end
  end

  def get_user_role(user_id, account_id) do
    case Repo.get_by(Member, user_id: user_id, account_id: account_id) do
      nil -> nil
      member -> member.role
    end
  end

  def user_has_account_access?(user_id, account_id) do
    Repo.exists?(from m in Member, where: m.user_id == ^user_id and m.account_id == ^account_id)
  end

  def user_has_any_account?(user_id) do
    Repo.exists?(from m in Member, where: m.user_id == ^user_id)
  end

  @doc """
  Returns true if the user is a member of at least one agency-type account.
  Used by the agency type guard on_mount.
  """
  def user_has_agency_account?(user_id) do
    Repo.exists?(
      from m in Member,
        join: a in Account,
        on: a.id == m.account_id,
        where: m.user_id == ^user_id and a.type == :agency
    )
  end

  @doc """
  Returns the first agency account for which the user is a member, or nil.
  Used to populate the agency context in the dashboard.
  """
  def get_user_agency_account(user_id) do
    from(a in Account,
      join: m in Member,
      on: m.account_id == a.id,
      where: m.user_id == ^user_id and a.type == :agency,
      order_by: [asc: a.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def can_add_user_to_account?(_account_id), do: true

  def count_account_users(account_id) do
    Repo.aggregate(from(m in Member, where: m.account_id == ^account_id), :count)
  end

  def list_user_accounts(user_id) do
    from(a in Account,
      join: m in Member,
      on: m.account_id == a.id,
      where: m.user_id == ^user_id,
      order_by: [desc: a.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns a list of accounts the user belongs to, each with the user's role
  embedded as a virtual `role` field on the account struct. Ordered by creation
  time (newest first) so that recently created accounts appear at the top.
  """
  def list_user_accounts_with_role(user_id) do
    from(a in Account,
      join: m in Member,
      on: m.account_id == a.id,
      where: m.user_id == ^user_id,
      order_by: [desc: a.inserted_at, desc: m.id],
      select: %{a | role: m.role}
    )
    |> Repo.all()
  end

  def list_account_users(account_id) do
    from(u in User,
      join: m in Member,
      on: m.user_id == u.id,
      where: m.account_id == ^account_id
    )
    |> Repo.all()
  end

  def list_account_members(account_id) do
    from(m in Member,
      where: m.account_id == ^account_id,
      preload: [:user]
    )
    |> Repo.all()
  end

  def list_accounts_with_role(user_id, role) do
    from(a in Account,
      join: m in Member,
      on: m.account_id == a.id,
      where: m.user_id == ^user_id and m.role == ^role
    )
    |> Repo.all()
  end

  def by_user(user_id), do: from(m in Member, where: m.user_id == ^user_id)
  def by_account(account_id), do: from(m in Member, where: m.account_id == ^account_id)
  def by_role(role), do: from(m in Member, where: m.role == ^role)
  def with_user_preloads, do: from(m in Member, preload: [:user])
  def with_account_preloads, do: from(m in Member, preload: [:account])

  defp count_owners(account_id) do
    Repo.aggregate(
      from(m in Member, where: m.account_id == ^account_id and m.role == :owner),
      :count
    )
  end
end
