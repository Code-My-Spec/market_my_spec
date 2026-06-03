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
    field :description, :string, required: false
    field :saved_searches, {:list, :map}, required: false
    field :money_gate, :map, required: false
    field :kill_condition, :map, required: false
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    frame_id = Map.fetch!(params, :frame_id)

    attrs =
      params
      |> Map.drop([:frame_id])
      |> Enum.into(%{}, fn
        {:saved_searches, list} -> {:saved_searches, normalize_list(list)}
        {:money_gate, map} -> {:money_gate, normalize_keys(map)}
        {:kill_condition, map} -> {:kill_condition, normalize_keys(map)}
        kv -> kv
      end)

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

  defp normalize_list(list) when is_list(list),
    do: Enum.map(list, &normalize_keys/1)

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp format(%Ecto.Changeset{errors: errors}) do
    Enum.map_join(errors, "; ", fn {f, {msg, _}} -> "#{f}: #{msg}" end)
  end
end
