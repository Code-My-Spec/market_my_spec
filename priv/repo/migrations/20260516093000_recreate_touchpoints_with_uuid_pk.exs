defmodule MarketMySpec.Repo.Migrations.RecreateTouchpointsWithUuidPk do
  use Ecto.Migration

  def up do
    drop table(:touchpoints)

    create table(:touchpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false
      add :state, :string
      add :angle, :string
      add :comment_url, :string
      add :polished_body, :text, null: false
      add :link_target, :string
      add :posted_at, :utc_datetime

      timestamps(type: :utc_datetime_usec)
    end

    create index(:touchpoints, [:account_id])
    create index(:touchpoints, [:account_id, :posted_at])
    create index(:touchpoints, [:thread_id])
  end

  def down do
    drop table(:touchpoints)

    create table(:touchpoints) do
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false
      add :state, :string
      add :angle, :string
      add :comment_url, :string
      add :polished_body, :text, null: false
      add :link_target, :string
      add :posted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:touchpoints, [:account_id])
    create index(:touchpoints, [:account_id, :posted_at])
    create index(:touchpoints, [:thread_id])
  end
end
