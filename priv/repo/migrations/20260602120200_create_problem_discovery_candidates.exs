defmodule MarketMySpec.Repo.Migrations.CreateProblemDiscoveryCandidates do
  use Ecto.Migration

  def change do
    create table(:problem_discovery_candidates, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :frame_id,
          references(:problem_discovery_frames, type: :binary_id, on_delete: :delete_all),
          null: false

      add :label, :string
      add :score, :integer, null: false, default: 0
      add :centroid, :vector, size: 1536, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:problem_discovery_candidates, [:frame_id])
  end
end
