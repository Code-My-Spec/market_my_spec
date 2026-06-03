defmodule MarketMySpec.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id,
          references(:chat_conversations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :role, :string, null: false
      add :content, :text, null: false, default: ""
      add :status, :string, null: false, default: "complete"

      add :provider, :string
      add :model, :string
      add :input_tokens, :integer
      add :output_tokens, :integer
      add :cost, :decimal
      add :finish_reason, :string
      add :response_id, :string
      add :error_reason, :text

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:conversation_id])
  end
end
