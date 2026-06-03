defmodule MarketMySpec.Repo.Migrations.AddTitleToProblemDiscoveryFrames do
  use Ecto.Migration

  # Frame had only `description` (long-form hypothesis). Founders + the
  # ProblemDiscovery LiveView read better with a short title + a longer
  # description: title is what shows in the frames index and the page
  # header; description is the full 1-3 sentence hypothesis.
  #
  # Existing rows get their description's leading slice copied into
  # title as a no-loss backfill, then NOT NULL is enforced.
  def up do
    alter table(:problem_discovery_frames) do
      add :title, :string, size: 256
    end

    # Backfill: title = first 80 chars of description (single line, no
    # leading/trailing space). Postgres `left(...)` is byte-safe at the
    # SQL level; for any pre-existing dev/test rows this is good enough
    # and the founder can edit afterward.
    execute """
            UPDATE problem_discovery_frames
            SET title = btrim(regexp_replace(left(description, 80), '\\s+', ' ', 'g'))
            WHERE title IS NULL
            """,
            "SELECT 1"

    alter table(:problem_discovery_frames) do
      modify :title, :string, size: 256, null: false
    end
  end

  def down do
    alter table(:problem_discovery_frames) do
      remove :title
    end
  end
end
