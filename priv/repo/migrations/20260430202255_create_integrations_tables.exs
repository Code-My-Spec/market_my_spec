defmodule MarketMySpec.Repo.Migrations.CreateIntegrationsTables do
  use Ecto.Migration

  def change do
    create table(:integrations) do
      add :provider, :string, null: false
      add :access_token, :binary, null: false
      add :refresh_token, :binary
      add :expires_at, :utc_datetime_usec
      add :granted_scopes, {:array, :string}, default: []
      add :provider_metadata, :map, default: %{}
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:integrations, [:user_id])
    create unique_index(:integrations, [:user_id, :provider])
  end
end
