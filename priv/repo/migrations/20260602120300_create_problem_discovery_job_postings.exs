defmodule MarketMySpec.Repo.Migrations.CreateProblemDiscoveryJobPostings do
  use Ecto.Migration

  def change do
    create table(:problem_discovery_job_postings, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :frame_id,
          references(:problem_discovery_frames, type: :binary_id, on_delete: :delete_all),
          null: false

      add :candidate_id,
          references(:problem_discovery_candidates, type: :binary_id, on_delete: :nilify_all),
          null: true

      add :saved_search_index, :integer, null: false
      add :source, :string, null: false
      add :source_id, :string, null: false
      add :title, :text, null: false
      add :description, :text, null: false
      add :url, :string
      add :total_spent_cents, :integer
      add :hire_rate, :integer
      add :pain_descriptor, :text
      add :embedding, :vector, size: 1536, null: false
      add :gathered_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:problem_discovery_job_postings, [:frame_id])
    create index(:problem_discovery_job_postings, [:candidate_id])
    create index(:problem_discovery_job_postings, [:frame_id, :saved_search_index])
    create unique_index(:problem_discovery_job_postings, [:frame_id, :source, :source_id])
  end
end
