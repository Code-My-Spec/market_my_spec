defmodule MarketMySpec.McpServers.Engagements.Tools.DeleteTouchpoint do
  @moduledoc """
  MCP tool: hard-delete a Touchpoint by id.

  No soft-delete / tombstone. The row is removed entirely. Cross-account
  access returns an error without modifying any row.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.TouchpointsRepository

  schema do
    field :touchpoint_id, :string, required: true, doc: "Touchpoint UUID to delete"
  end

  @impl true
  def execute(%{touchpoint_id: touchpoint_id}, frame) do
    scope = frame.assigns.current_scope

    case TouchpointsRepository.delete_touchpoint(scope, touchpoint_id) do
      {:ok, _touchpoint} ->
        payload = %{"deleted" => true, "touchpoint_id" => touchpoint_id}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, :not_found} ->
        err = Jason.encode!(%{"error" => "not_found", "message" => "Touchpoint not found: #{touchpoint_id}"})
        {:reply, Response.tool() |> Response.text(err) |> Map.put(:isError, true), frame}

      {:error, reason} ->
        err = Jason.encode!(%{"error" => "delete_failed", "message" => inspect(reason)})
        {:reply, Response.tool() |> Response.text(err) |> Map.put(:isError, true), frame}
    end
  end
end
