defmodule MarketMySpec.Repo.Migrations.AddActiveAccountToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :active_account_id,
          references(:accounts, type: :binary_id, on_delete: :nilify_all),
          null: true
    end
  end
end
