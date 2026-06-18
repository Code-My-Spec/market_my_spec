defmodule MarketMySpec.Repo.Migrations.WidenThreadsUrlAndTitle do
  use Ecto.Migration

  # `threads.url` and `threads.title` were created as `:string`, which Postgres
  # renders as `varchar(255)`. The Thread changeset, however, allows `url` up to
  # 2048 chars and `title` up to 500. Reddit URLs (whose slug is derived from the
  # post title) routinely exceed 255 chars, so an over-length value passed the
  # changeset and then hit the DB, raising Postgrex `22001
  # string_data_right_truncation` — an unhandled raise (not a changeset error)
  # that crashed the search fan-out task and surfaced as `-32603 Server
  # unavailable` in the MCP layer.
  #
  # Switching both columns to `:text` removes the 255 ceiling; the changeset's
  # `validate_length` limits (2048 / 500) become the real gate, and an
  # over-length candidate now degrades to `{:error, changeset}` (dropped) rather
  # than raising.
  def change do
    alter table(:threads) do
      modify :url, :text, from: :string
      modify :title, :text, from: :string
    end
  end
end
