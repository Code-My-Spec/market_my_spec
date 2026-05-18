defmodule MarketMySpec.Repo.Migrations.AddSynopsisToThreads do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :synopsis, :text, null: true
    end
  end
end
