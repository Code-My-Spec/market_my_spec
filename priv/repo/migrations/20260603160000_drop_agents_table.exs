defmodule MarketMySpec.Repo.Migrations.DropAgentsTable do
  use Ecto.Migration

  # The MMS Agent (residential-IP proxy binary) is retired — Reddit RSS is
  # served fine from the server's datacenter IP, so the agent transport and
  # its pairing/token storage are no longer needed.
  def up do
    drop table(:agents)
  end

  def down do
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
end
