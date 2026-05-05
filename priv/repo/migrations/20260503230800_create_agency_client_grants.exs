defmodule MarketMySpec.Repo.Migrations.CreateAgencyClientGrants do
  use Ecto.Migration

  def change do
    create table(:agency_client_grants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agency_account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :client_account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :access_level, :string, null: false, default: "read_only"
      add :status, :string, null: false, default: "accepted"
      add :originator, :string, null: false
      add :created_by_user_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:agency_client_grants, [:agency_account_id, :client_account_id])
    create index(:agency_client_grants, [:agency_account_id])
    create index(:agency_client_grants, [:client_account_id])
  end
end
