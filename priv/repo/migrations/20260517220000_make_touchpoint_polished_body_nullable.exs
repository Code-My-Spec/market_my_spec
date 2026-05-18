defmodule MarketMySpec.Repo.Migrations.MakeTouchpointPolishedBodyNullable do
  @moduledoc """
  Drop NOT NULL on touchpoints.polished_body.

  Agents may stage a touchpoint before Sam dictates his rough draft — body
  fills in later via update_touchpoint or the LiveView edit form. The
  Touchpoint.staged_changeset already treats polished_body as optional;
  this aligns the DB schema with that semantic.
  """
  use Ecto.Migration

  def change do
    alter table(:touchpoints) do
      modify :polished_body, :text, null: true, from: {:text, null: false}
    end
  end
end
