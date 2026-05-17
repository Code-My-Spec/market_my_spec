defmodule MarketMySpec.Repo.Migrations.AddLastActivityAtToThreads do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :last_activity_at, :utc_datetime, null: true
    end

    create index(:threads, [:account_id, :last_activity_at])
  end
end
