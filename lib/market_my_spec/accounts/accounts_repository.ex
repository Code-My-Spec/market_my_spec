defmodule MarketMySpec.Accounts.AccountsRepository do
  import Ecto.Query, warn: false
  alias MarketMySpec.Repo
  alias MarketMySpec.Accounts.{Account, Member}

  def create_account(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  def get_account(id), do: Repo.get(Account, id)
  def get_account!(id), do: Repo.get!(Account, id)

  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  def delete_account(%Account{} = account), do: Repo.delete(account)

  def create_account_with_owner(attrs, owner_id) do
    Repo.transaction(fn ->
      with {:ok, account} <- create_account(attrs),
           {:ok, _member} <-
             create_member(%{user_id: owner_id, account_id: account.id, role: :owner}) do
        account
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def by_slug(slug), do: from(a in Account, where: a.slug == ^slug)
  def with_preloads(preloads), do: from(a in Account, preload: ^preloads)

  defp create_member(attrs) do
    %Member{}
    |> Member.changeset(attrs)
    |> Repo.insert()
  end
end
