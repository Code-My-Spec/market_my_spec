defmodule MarketMySpec.Repo.Migrations.AddSubdomainToAccounts do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :subdomain, :string
    end

    create unique_index(:accounts, [:subdomain],
             where: "subdomain IS NOT NULL",
             name: :accounts_subdomain_index
           )
  end
end
