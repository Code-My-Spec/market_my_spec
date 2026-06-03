defmodule MarketMySpec.Repo.Migrations.AddChatTypeAndToolFields do
  use Ecto.Migration

  def change do
    alter table(:chat_conversations) do
      add :type, :string
    end

    alter table(:chat_messages) do
      add :tool_name, :string
      add :tool_call_id, :string
      add :tool_calls, {:array, :map}
    end
  end
end
