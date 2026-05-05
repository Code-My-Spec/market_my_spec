defmodule MarketMySpec.Accounts.Member do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{
          id: integer(),
          role: :owner | :admin | :member,
          user_id: integer(),
          account_id: Ecto.UUID.t(),
          user: MarketMySpec.Users.User.t() | Ecto.Association.NotLoaded.t(),
          account: MarketMySpec.Accounts.Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "members" do
    field :role, Ecto.Enum, values: [:owner, :admin, :member], default: :member

    belongs_to :user, MarketMySpec.Users.User
    belongs_to :account, MarketMySpec.Accounts.Account, type: :binary_id

    timestamps()
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:role, :user_id, :account_id])
    |> validate_required([:role, :user_id, :account_id])
    |> validate_inclusion(:role, [:owner, :admin, :member])
    |> assoc_constraint(:user)
    |> assoc_constraint(:account)
    |> unique_constraint([:user_id, :account_id], name: :members_user_id_account_id_index)
  end

  def update_role_changeset(member, attrs) do
    member
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, [:owner, :admin, :member])
  end

  def validate_owner_exists(changeset, repo) do
    case get_field(changeset, :role) do
      :owner ->
        changeset

      _ ->
        user_id = get_field(changeset, :user_id)
        account_id = get_field(changeset, :account_id)
        validate_not_last_owner(changeset, repo, user_id, account_id)
    end
  end

  defp validate_not_last_owner(changeset, _repo, nil, _account_id), do: changeset
  defp validate_not_last_owner(changeset, _repo, _user_id, nil), do: changeset

  defp validate_not_last_owner(changeset, repo, user_id, account_id) do
    case repo.get_by(__MODULE__, user_id: user_id, account_id: account_id) do
      %{role: :owner} -> check_owner_count(changeset, repo, account_id)
      _ -> changeset
    end
  end

  defp check_owner_count(changeset, repo, account_id) do
    owner_count =
      repo.aggregate(
        from(m in __MODULE__, where: m.account_id == ^account_id and m.role == :owner),
        :count
      )

    if owner_count <= 1 do
      add_error(changeset, :role, "account must have at least one owner")
    else
      changeset
    end
  end

  def has_role?(member, required_role) do
    role_hierarchy = %{member: 1, admin: 2, owner: 3}
    Map.get(role_hierarchy, member.role, 0) >= Map.get(role_hierarchy, required_role, 0)
  end

  def owner?(member), do: member.role == :owner
  def admin_or_owner?(member), do: member.role in [:admin, :owner]
end
