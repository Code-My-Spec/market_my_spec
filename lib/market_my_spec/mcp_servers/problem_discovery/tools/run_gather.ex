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
    field :mode, :string, required: false, doc: "\"probe\" or default (committed run)"
    field :limit, :integer, required: false
    field :force, :boolean, required: false

    # Probe-mode draft Frame — flattened to primitives because the agent
    # was hitting Anubis/Peri -32602 on nested :map params. Only used
    # when mode=\"probe\".
    field :description, :string,
      required: false,
      doc: "Probe mode: draft Frame's hypothesis statement"

    field :saved_searches, {:list, :string},
      required: false,
      doc: "Probe mode: list of \"source|query\" strings to sample against"

    field :total_spent_min, :integer,
      required: false,
      doc: "Probe mode: money-gate threshold (paired with :hire_rate_min)"

    field :hire_rate_min, :integer, required: false, doc: "Probe mode: money-gate threshold"

    field :min_money_gated_candidates, :integer,
      required: false,
      doc: "Probe mode: kill-condition threshold"
  end

  @impl true
  def execute(%{mode: "probe"} = params, frame) do
    scope = frame.assigns.current_scope
    draft = build_draft(params)

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

  defp build_draft(params) do
    %{
      description: Map.get(params, :description),
      saved_searches: parse_saved_searches(Map.get(params, :saved_searches, [])),
      money_gate: %{
        total_spent_min: Map.get(params, :total_spent_min),
        hire_rate_min: Map.get(params, :hire_rate_min)
      },
      kill_condition: %{
        min_money_gated_candidates: Map.get(params, :min_money_gated_candidates)
      }
    }
  end

  defp parse_saved_searches(list) when is_list(list) do
    Enum.map(list, fn entry ->
      case String.split(entry, "|", parts: 2) do
        [source, query] -> %{source: String.trim(source), query: String.trim(query)}
        [single] -> %{source: "upwork", query: String.trim(single)}
      end
    end)
  end
end
