defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.ListFrames do
  @moduledoc """
  MCP tool: list Frames on the active account.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
  end

  @impl true
  def execute(_params, frame) do
    scope = frame.assigns.current_scope
    frames = ProblemDiscovery.list_frames(scope)

    payload = %{frames: Enum.map(frames, &encode/1)}
    {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}
  end

  defp encode(f) do
    %{
      id: f.id,
      title: f.title,
      description: f.description,
      saved_search_count: length(f.saved_searches),
      money_gate: f.money_gate,
      kill_condition: f.kill_condition,
      inserted_at: f.inserted_at,
      updated_at: f.updated_at
    }
  end
end
