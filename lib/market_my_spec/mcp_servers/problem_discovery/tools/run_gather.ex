defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather do
  @moduledoc """
  MCP tool: run Gather for a Frame.

  - Default mode: additive per-saved-search Gather over the committed
    Frame. Returns per-saved-search gathered/failed counts.
  - Probe mode: small-sample Gather against an uncommitted draft Frame
    (passed in `frame` param) for Frame composition validation
    (criterion 6580). Returns a sample without persisting.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :frame_id, :string, required: false, doc: "Committed Frame id (default mode)"
    field :frame, :map, required: false, doc: "Draft Frame (probe mode)"
    field :mode, :string, required: false, doc: "\"probe\" or default (committed run)"
    field :limit, :integer, required: false
    field :force, :boolean, required: false
  end

  @impl true
  def execute(%{mode: "probe"} = params, frame) do
    scope = frame.assigns.current_scope
    draft = Map.fetch!(params, :frame) |> normalize_draft()

    case ProblemDiscovery.probe_gather(scope, draft, limit: Map.get(params, :limit, 20)) do
      {:ok, payload} ->
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error(inspect(reason)), frame}
    end
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    frame_id = Map.fetch!(params, :frame_id)
    opts = if Map.get(params, :force), do: [force: true], else: []

    case ProblemDiscovery.run_gather(scope, frame_id, opts) do
      {:ok, payload} ->
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error(inspect(reason)), frame}
    end
  end

  defp normalize_draft(map) when is_map(map) do
    %{
      description: Map.get(map, :description) || Map.get(map, "description"),
      saved_searches:
        (Map.get(map, :saved_searches) || Map.get(map, "saved_searches") || [])
        |> Enum.map(&normalize_keys/1),
      money_gate: normalize_keys(Map.get(map, :money_gate) || Map.get(map, "money_gate") || %{}),
      kill_condition:
        normalize_keys(Map.get(map, :kill_condition) || Map.get(map, "kill_condition") || %{})
    }
  end

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
