defmodule MarketMySpec.Repo.Migrations.MakeTouchpointCommentUrlPostedAtNullable do
  use Ecto.Migration

  def change do
    alter table(:touchpoints) do
      modify :comment_url, :string, null: true, from: {:string, null: false}
      modify :posted_at, :utc_datetime, null: true, from: {:utc_datetime, null: false}
    end
  end
end
