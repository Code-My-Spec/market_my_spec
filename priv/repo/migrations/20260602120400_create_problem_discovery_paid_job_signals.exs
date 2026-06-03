defmodule MarketMySpec.Repo.Migrations.CreateProblemDiscoveryPaidJobSignals do
  use Ecto.Migration

  def change do
    create table(:problem_discovery_paid_job_signals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :job_posting_id,
          references(:problem_discovery_job_postings, type: :binary_id, on_delete: :delete_all),
          null: false

      add :candidate_id,
          references(:problem_discovery_candidates, type: :binary_id, on_delete: :delete_all),
          null: false

      add :classification, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:problem_discovery_paid_job_signals, [:job_posting_id])
    create index(:problem_discovery_paid_job_signals, [:candidate_id])
    create index(:problem_discovery_paid_job_signals, [:candidate_id, :classification])
  end
end
