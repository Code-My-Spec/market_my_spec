defmodule MarketMySpec.Repo.Migrations.CreateTouchpoints do
  use Ecto.Migration

  def change do
    create table(:touchpoints) do
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false
      add :comment_url, :string, null: false
      add :polished_body, :text, null: false
      add :link_target, :string
      add :posted_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:touchpoints, [:account_id])
    create index(:touchpoints, [:account_id, :posted_at])
    create index(:touchpoints, [:thread_id])
  end
end
