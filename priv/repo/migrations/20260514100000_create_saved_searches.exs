defmodule MarketMySpec.Repo.Migrations.CreateSavedSearches do
  use Ecto.Migration

  def change do
    create table(:saved_searches) do
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :query, :string, null: false
      add :source_wildcards, {:array, :string}, null: false, default: []

      timestamps()
    end

    create index(:saved_searches, [:account_id])
    create unique_index(:saved_searches, [:account_id, :name])

    create table(:saved_search_venues) do
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :saved_search_id, references(:saved_searches, on_delete: :delete_all), null: false
      add :venue_id, references(:venues, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:saved_search_venues, [:account_id])
    create index(:saved_search_venues, [:saved_search_id])
    create index(:saved_search_venues, [:venue_id])
    create unique_index(:saved_search_venues, [:saved_search_id, :venue_id])
  end
end
