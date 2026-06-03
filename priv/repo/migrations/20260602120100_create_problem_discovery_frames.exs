defmodule MarketMySpec.Repo.Migrations.CreateProblemDiscoveryFrames do
  use Ecto.Migration

  def change do
    create table(:problem_discovery_frames, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :description, :text, null: false
      add :saved_searches, {:array, :map}, null: false, default: []
      add :money_gate, :map, null: false
      add :kill_condition, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:problem_discovery_frames, [:account_id])
  end
end
