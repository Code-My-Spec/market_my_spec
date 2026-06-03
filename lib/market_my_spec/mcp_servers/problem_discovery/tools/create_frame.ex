defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame do
  @moduledoc """
  MCP tool: create a Frame with description, saved searches, money_gate
  threshold, and kill_condition (story 742).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :description, :string, required: true, doc: "Hypothesis statement (1-3 sentences)"

    field :saved_searches, {:list, :map},
      required: true,
      doc: "[{\"source\": \"upwork\", \"query\": \"...\"}, ...]"

    field :money_gate, :map,
      required: true,
      doc: "%{\"total_spent_min\": int, \"hire_rate_min\": int}"

    field :kill_condition, :map,
      required: true,
      doc: "%{\"min_money_gated_candidates\": int}"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope

    attrs = %{
      description: Map.fetch!(params, :description),
      saved_searches: normalize_saved_searches(Map.fetch!(params, :saved_searches)),
      money_gate: normalize_keys(Map.fetch!(params, :money_gate)),
      kill_condition: normalize_keys(Map.fetch!(params, :kill_condition))
    }

    case ProblemDiscovery.create_frame(scope, attrs) do
      {:ok, created} ->
        {:reply,
         Response.tool() |> Response.text(Jason.encode!(%{frame_id: created.id})),
         frame}

      {:error, changeset} ->
        {:reply, Response.tool() |> Response.error(format(changeset)), frame}
    end
  end

  defp normalize_saved_searches(list) when is_list(list) do
    Enum.map(list, fn entry -> normalize_keys(entry) end)
  end

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
