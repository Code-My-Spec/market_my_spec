defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.UpdateFrame do
  @moduledoc """
  MCP tool: update a Frame's description, money_gate, kill_condition, or
  saved searches. Adding a saved search makes it eligible for the next
  per-saved-search Gather run (additive).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :frame_id, :string, required: true

    field :title, :string,
      required: false,
      max_length: 256,
      doc: "Short label shown in the frames index + page header."

    # Explicit max_length so MCP clients don't impose a default short cap
    # client-side (~256) and silently reject natural-length prose.
    field :description, :string, required: false, max_length: 4096

    field :saved_searches, {:list, :string},
      required: false,
      doc:
        "List of pipe-separated `\"source|query\"` strings. Pass to replace the full set; omit to leave saved_searches untouched."

    field :total_spent_min, :integer,
      required: false,
      doc:
        "Money-gate threshold update — pair with :hire_rate_min. Both must be supplied together to change the gate."

    field :hire_rate_min, :integer,
      required: false,
      doc: "Money-gate threshold update — pair with :total_spent_min."

    field :min_money_gated_candidates, :integer,
      required: false,
      doc: "Kill-condition update."
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    frame_id = Map.fetch!(params, :frame_id)

    attrs =
      %{}
      |> maybe_put(:title, Map.get(params, :title))
      |> maybe_put(:description, Map.get(params, :description))
      |> maybe_put_saved_searches(Map.get(params, :saved_searches))
      |> maybe_put_money_gate(
        Map.get(params, :total_spent_min),
        Map.get(params, :hire_rate_min)
      )
      |> maybe_put_kill_condition(Map.get(params, :min_money_gated_candidates))

    case ProblemDiscovery.update_frame(scope, frame_id, attrs) do
      {:ok, updated} ->
        {:reply,
         Response.tool() |> Response.text(Jason.encode!(%{frame_id: updated.id})),
         frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Frame not found"), frame}

      {:error, changeset} ->
        {:reply, Response.tool() |> Response.error(format(changeset)), frame}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_saved_searches(map, nil), do: map

  defp maybe_put_saved_searches(map, list) when is_list(list) do
    parsed =
      Enum.map(list, fn entry ->
        case String.split(entry, "|", parts: 2) do
          [source, query] -> %{source: String.trim(source), query: String.trim(query)}
          [single] -> %{source: "upwork", query: String.trim(single)}
        end
      end)

    Map.put(map, :saved_searches, parsed)
  end

  defp maybe_put_money_gate(map, nil, nil), do: map

  defp maybe_put_money_gate(map, total_spent_min, hire_rate_min)
       when is_integer(total_spent_min) and is_integer(hire_rate_min) do
    Map.put(map, :money_gate, %{
      total_spent_min: total_spent_min,
      hire_rate_min: hire_rate_min
    })
  end

  defp maybe_put_money_gate(_map, _t, _h),
    do: raise(ArgumentError, "money_gate update requires both :total_spent_min and :hire_rate_min")

  defp maybe_put_kill_condition(map, nil), do: map

  defp maybe_put_kill_condition(map, n) when is_integer(n),
    do: Map.put(map, :kill_condition, %{min_money_gated_candidates: n})

  defp format(%Ecto.Changeset{errors: errors}) do
    Enum.map_join(errors, "; ", fn {f, {msg, _}} -> "#{f}: #{msg}" end)
  end
end
