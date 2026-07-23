defmodule MarketMySpec.Repo.Migrations.RecreateAgentsTable do
  use Ecto.Migration

  # The MMS Agent is back. The 2026-06-03 retirement assumed Reddit RSS was
  # served fine from the server's datacenter IP; live measurement since then
  # (see Engagements.RateLimiter moduledoc) put that IP at ~1 request per 60s
  # window, so reads move back onto a paired residential-IP binary.
  #
  # Schema is identical to 20260519000000_create_agents — this is the `down`
  # of 20260603160000_drop_agents_table, replayed forward.
  def up do
    create table(:agents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :version, :string
      add :status, :string, null: false, default: "active"
      add :last_seen_at, :utc_datetime_usec
      add :paired_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      add :encrypted_token, :binary, null: false
      add :token_hash, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:agents, [:user_id])
    create unique_index(:agents, [:token_hash])
  end

  def down do
    drop table(:agents)
  end
end
