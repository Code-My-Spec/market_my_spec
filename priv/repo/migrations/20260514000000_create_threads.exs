defmodule MarketMySpec.Repo.Migrations.CreateThreads do
  use Ecto.Migration

  def change do
    create table(:threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source, :string, null: false
      add :source_thread_id, :string, null: false
      add :url, :string, null: false
      add :title, :string, null: false
      add :op_body, :text
      add :comment_tree, :map, null: false, default: %{}
      add :raw_payload, :map, null: false, default: %{}
      add :fetched_at, :utc_datetime, null: false
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:threads, [:account_id])
    create index(:threads, [:account_id, :fetched_at])
    create unique_index(:threads, [:account_id, :source, :source_thread_id])
  end
end
