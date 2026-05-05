defmodule MarketMySpec.Accounts.AccountsRepository do
  @moduledoc """
  Repository for account CRUD operations and account-with-owner creation.
  """

  import Ecto.Query, warn: false

  alias MarketMySpec.Accounts.{Account, Member}
  alias MarketMySpec.Repo

  def create_account(attrs) do
    Account.create_changeset(attrs)
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

  @doc """
  Creates an agency-typed account with the given user as owner.
  Uses the admin changeset that allows setting account type, bypassing
  the self-service restriction to individual accounts only.
  """
  def create_agency_account_with_owner(attrs, owner_id) do
    Repo.transaction(fn ->
      with {:ok, account} <- create_agency_account(attrs),
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

  defp create_agency_account(attrs) do
    %Account{}
    |> Account.admin_changeset(attrs)
    |> maybe_generate_slug()
    |> Repo.insert()
  end

  defp maybe_generate_slug(changeset) do
    case Ecto.Changeset.get_field(changeset, :slug) do
      nil ->
        name = Ecto.Changeset.get_field(changeset, :name)

        if name do
          slug =
            name
            |> String.downcase()
            |> String.replace(~r/[^a-z0-9]/, "-")
            |> String.replace(~r/-+/, "-")
            |> String.trim("-")

          Ecto.Changeset.put_change(changeset, :slug, slug)
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp create_member(attrs) do
    %Member{}
    |> Member.changeset(attrs)
    |> Repo.insert()
  end
end
