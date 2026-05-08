defmodule MarketMySpec.Repo.Migrations.AddBrandingToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :logo_url, :string
      add :primary_color, :string
      add :secondary_color, :string
    end
  end
end
