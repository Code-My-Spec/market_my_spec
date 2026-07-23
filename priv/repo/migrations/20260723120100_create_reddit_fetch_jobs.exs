defmodule MarketMySpec.Repo.Migrations.CreateRedditFetchJobs do
  use Ecto.Migration

  # Reddit allows ~1 request per 60s per IP, so a multi-venue search cannot
  # complete inside a request/response cycle. Fetches become queued work:
  # Search enqueues one job per venue and reads the last completed job's
  # candidates, while the drain worker feeds jobs to the paired agent at the
  # rate Reddit actually permits.
  def change do
    create table(:reddit_fetch_jobs) do
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :venue_id, references(:venues, on_delete: :delete_all)

      add :kind, :string, null: false

      # `""` rather than NULL for the three identity columns so the partial
      # unique index below actually dedupes — Postgres treats NULLs as
      # distinct, which would let identical pending jobs pile up.
      add :query, :string, null: false, default: ""
      add :cursor, :string, null: false, default: ""
      add :source_thread_id, :string, null: false, default: ""

      add :request, :map, null: false, default: %{}

      add :status, :string, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :last_error, :text

      # Result of the last successful run, read back by Search.
      add :candidates, {:array, :map}
      add :next_cursor, :string

      add :enqueued_at, :utc_datetime, null: false
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Drain pick: oldest pending job first.
    create index(:reddit_fetch_jobs, [:status, :id])

    # Read path: newest completed job for a venue + query.
    create index(:reddit_fetch_jobs, [:account_id, :venue_id, :query, :status])

    # One pending job per unit of work — re-running a search while its
    # fetches are still queued must not multiply the queue depth.
    create unique_index(
             :reddit_fetch_jobs,
             [:account_id, :venue_id, :query, :cursor, :source_thread_id],
             where: "status = 'pending'",
             name: :reddit_fetch_jobs_pending_unique_index
           )
  end
end
