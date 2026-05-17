defmodule MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints do
  @moduledoc """
  MCP tool: list all Touchpoints for a Thread, ordered newest-first.

  Returns only the calling account's touchpoints. Cross-account thread_ids
  return an empty list (no data leak).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.TouchpointsRepository

  schema do
    field :thread_id, :string, required: true, doc: "Thread UUID"
  end

  @impl true
  def execute(%{thread_id: thread_id}, frame) do
    scope = frame.assigns.current_scope

    touchpoints =
      TouchpointsRepository.list_touchpoints_for_thread(scope, thread_id)
      |> Enum.map(&encode_touchpoint/1)

    payload = %{"touchpoints" => touchpoints}
    {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}
  end

  defp encode_touchpoint(tp) do
    %{
      "id" => tp.id,
      "state" => tp.state && to_string(tp.state),
      "angle" => tp.angle,
      "polished_body" => tp.polished_body,
      "link_target" => tp.link_target,
      "comment_url" => tp.comment_url,
      "posted_at" => tp.posted_at && DateTime.to_iso8601(tp.posted_at),
      "inserted_at" => tp.inserted_at && DateTime.to_iso8601(tp.inserted_at)
    }
  end
end
