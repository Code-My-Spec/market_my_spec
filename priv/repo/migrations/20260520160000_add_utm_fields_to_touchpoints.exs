defmodule MarketMySpec.Repo.Migrations.AddUtmFieldsToTouchpoints do
  use Ecto.Migration

  def change do
    alter table(:touchpoints) do
      add :utm_source, :string
      add :utm_medium, :string
      add :utm_campaign, :string
    end
  end
end
