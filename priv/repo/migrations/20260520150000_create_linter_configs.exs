defmodule MarketMySpec.Repo.Migrations.CreateLinterConfigs do
  use Ecto.Migration

  def change do
    create table(:linter_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :account_id,
          references(:accounts, type: :binary_id, on_delete: :delete_all),
          null: false

      add :vale_ini, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:linter_configs, [:account_id])
  end
end
