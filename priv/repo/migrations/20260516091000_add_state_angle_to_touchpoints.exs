defmodule MarketMySpec.Repo.Migrations.AddStateAngleToTouchpoints do
  use Ecto.Migration

  def change do
    alter table(:touchpoints) do
      add :state, :string, null: true
      add :angle, :string, null: true
    end
  end
end
