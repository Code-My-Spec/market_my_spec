defmodule MarketMySpec.Repo.Migrations.AlignSavedSearchesSchema do
  @moduledoc """
  Forward-only fix for schema drift on `saved_searches`.

  An earlier revision of migration `20260514100000_create_saved_searches`
  shipped columns `keywords` (array of strings), `venue_identifiers`
  (array of strings), and `venue_source` (single string enum). That
  shape was reverted to the agreed design (single Google-style `query`
  string + `source_wildcards` array of strings) and the migration file
  was rewritten in place.

  Dev databases that ran the original version of `20260514100000`
  recorded that version in `schema_migrations`, so `mix ecto.migrate`
  reports "already up" and the rewritten migration content never runs.
  Those tables still have the old columns; the app throws
  `column "query" does not exist` on every page load.

  This migration brings any pre-existing `saved_searches` table forward
  to the agreed shape without requiring `mix ecto.reset`:

  - Add `query :text NOT NULL DEFAULT ''` if missing, then drop the
    default (the SavedSearch changeset enforces non-empty at the app
    layer).
  - Add `source_wildcards {:array, :string}` if missing.
  - Drop legacy `keywords`, `venue_identifiers`, `venue_source` if
    present.

  Fresh environments that ran the rewritten `20260514100000` already
  have the target shape; the `IF NOT EXISTS` / `IF EXISTS` clauses make
  this idempotent there.
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE saved_searches ADD COLUMN IF NOT EXISTS query text NOT NULL DEFAULT ''")
    execute("ALTER TABLE saved_searches ALTER COLUMN query DROP DEFAULT")

    execute("""
    ALTER TABLE saved_searches
      ADD COLUMN IF NOT EXISTS source_wildcards text[] NOT NULL DEFAULT ARRAY[]::text[]
    """)

    execute("ALTER TABLE saved_searches DROP COLUMN IF EXISTS keywords")
    execute("ALTER TABLE saved_searches DROP COLUMN IF EXISTS venue_identifiers")
    execute("ALTER TABLE saved_searches DROP COLUMN IF EXISTS venue_source")
  end

  def down do
    # No automatic restoration of the legacy columns — the previous
    # design is gone for good. A targeted rollback should `mix ecto.reset`
    # if it really needs the old shape.
    :ok
  end
end
