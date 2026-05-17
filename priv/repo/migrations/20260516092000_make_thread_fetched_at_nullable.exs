defmodule MarketMySpec.Repo.Migrations.MakeThreadFetchedAtNullable do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      modify :fetched_at, :utc_datetime, null: true, from: {:utc_datetime, null: false}
    end
  end
end
