defmodule MarketMySpec.Repo.Migrations.AddTitleToProblemDiscoveryFrames do
  use Ecto.Migration

  # Frame had only `description` (long-form hypothesis). Founders + the
  # ProblemDiscovery LiveView read better with a short title + a longer
  # description: title is what shows in the frames index and the page
  # header; description is the full 1-3 sentence hypothesis.
  #
  # Existing rows get their description's leading slice copied into
  # title as a no-loss backfill, then NOT NULL is enforced.
  # Idempotent: an earlier partial apply left the `title` column on some
  # environments (e.g. prod) without recording this migration, so a plain
  # `add :title` re-runs and fails with duplicate_column. Each step is written
  # to be safe whether or not the column already exists.
  def up do
    execute "ALTER TABLE problem_discovery_frames ADD COLUMN IF NOT EXISTS title varchar(256)"

    # Backfill: title = first 80 chars of description (single line, no
    # leading/trailing space). Idempotent — only touches rows still NULL.
    execute """
            UPDATE problem_discovery_frames
            SET title = btrim(regexp_replace(left(description, 80), '\\s+', ' ', 'g'))
            WHERE title IS NULL
            """

    execute "ALTER TABLE problem_discovery_frames ALTER COLUMN title SET NOT NULL"
  end

  def down do
    execute "ALTER TABLE problem_discovery_frames DROP COLUMN IF EXISTS title"
  end
end
