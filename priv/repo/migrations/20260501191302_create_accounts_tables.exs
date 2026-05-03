defmodule MarketMySpec.Repo.Migrations.CreateAccountsTables do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string

      timestamps()
    end

    create unique_index(:accounts, [:slug])

    create table(:members) do
      add :role, :string, null: false, default: "member"
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:members, [:user_id])
    create index(:members, [:account_id])
    create unique_index(:members, [:user_id, :account_id])

    create table(:invitations) do
      add :token_hash, :binary, null: false
      add :email, :string, null: false
      add :role, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime, null: false
      add :accepted_at, :utc_datetime
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :invited_by_user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:invitations, [:account_id])
    create index(:invitations, [:email])
    create unique_index(:invitations, [:token_hash])
  end
end
