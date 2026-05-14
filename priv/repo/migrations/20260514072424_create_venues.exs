defmodule MarketMySpec.Repo.Migrations.CreateVenues do
  use Ecto.Migration

  def change do
    create table(:venues) do
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :source, :string, null: false
      add :identifier, :string, null: false
      add :weight, :float, null: false, default: 1.0
      add :enabled, :boolean, null: false, default: true

      timestamps()
    end

    create index(:venues, [:account_id])
    create index(:venues, [:account_id, :source])
  end
end
