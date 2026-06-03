defmodule MarketMySpec.Repo.Migrations.CreateChatConversations do
  use Ecto.Migration

  def change do
    create table(:chat_conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false, default: "anthropic"
      add :model, :string, null: false
      add :title, :string

      timestamps(type: :utc_datetime)
    end

    create index(:chat_conversations, [:account_id])
  end
end
