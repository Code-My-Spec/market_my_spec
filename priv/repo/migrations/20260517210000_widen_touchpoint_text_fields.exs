defmodule MarketMySpec.Repo.Migrations.WidenTouchpointTextFields do
  @moduledoc """
  Widen angle / link_target / comment_url from varchar(255) to text.

  `polished_body` was already :text. `angle` is the agent's reasoning paragraph
  and easily exceeds 255 chars. Reddit comment URLs include post slugs + comment
  IDs and can also exceed 255.

  Triggered after a stage_response call crashed with:
    ERROR 22001 (string_data_right_truncation)
    value too long for type character varying(255)
  on a 400-char angle value.
  """
  use Ecto.Migration

  def change do
    alter table(:touchpoints) do
      modify :angle, :text, from: :string
      modify :link_target, :text, from: :string
      modify :comment_url, :text, from: :string
    end
  end
end
