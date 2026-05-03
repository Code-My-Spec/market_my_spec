defmodule MarketMySpec.Accounts.MembersRepository do
  import Ecto.Query, warn: false

  alias MarketMySpec.Repo
  alias MarketMySpec.Accounts.{Account, Member}
  alias MarketMySpec.Users.User

  def add_user_to_account(user_id, account_id, role \\ :member) do
    %Member{}
    |> Member.changeset(%{user_id: user_id, account_id: account_id, role: role})
    |> Repo.insert()
  end

  def remove_user_from_account(user_id, account_id) do
    case Repo.get_by(Member, user_id: user_id, account_id: account_id) do
      nil ->
        {:error, :not_found}

      member ->
        case member.role do
          :owner ->
            owner_count = count_owners(account_id)
            if owner_count > 1, do: Repo.delete(member), else: {:error, :last_owner}

          _ ->
            Repo.delete(member)
        end
    end
  end

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

  def can_add_user_to_account?(_account_id), do: true

  def count_account_users(account_id) do
    Repo.aggregate(from(m in Member, where: m.account_id == ^account_id), :count)
  end

  def list_user_accounts(user_id) do
    from(a in Account,
      join: m in Member,
      on: m.account_id == a.id,
      where: m.user_id == ^user_id
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
