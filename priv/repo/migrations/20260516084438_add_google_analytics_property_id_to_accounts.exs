defmodule MarketMySpec.Repo.Migrations.AddGoogleAnalyticsPropertyIdToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :google_analytics_property_id, :string
    end
  end
end
