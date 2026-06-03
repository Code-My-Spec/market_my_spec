defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame do
  @moduledoc """
  MCP tool: create a Frame with description, saved searches, money_gate
  threshold, and kill_condition (story 742).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    # Explicit max_length so MCP clients don't impose a default short cap
    # client-side (~256) and silently reject natural-length hypothesis prose.
    field :description, :string,
      required: true,
      max_length: 4096,
      doc: "Hypothesis statement (1-3 sentences). Up to 4096 chars."

    field :saved_searches, {:list, :string},
      required: true,
      doc:
        "List of pipe-separated `\"source|query\"` strings, e.g. [\"upwork|vendor onboarding\", \"upwork|supplier portal\"]"

    field :total_spent_min, :integer,
      required: true,
      doc: "Money-gate threshold: minimum client total_spent (USD) for a JobPosting to gate in"

    field :hire_rate_min, :integer,
      required: true,
      doc: "Money-gate threshold: minimum client hire_rate (0-100) for a JobPosting to gate in"

    field :min_money_gated_candidates, :integer,
      required: true,
      doc:
        "Kill condition: minimum count of money-gated Candidates the pipeline must produce to be considered a survivable Frame"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope

    attrs = %{
      description: Map.fetch!(params, :description),
      saved_searches: parse_saved_searches(Map.fetch!(params, :saved_searches)),
      money_gate: %{
        total_spent_min: Map.fetch!(params, :total_spent_min),
        hire_rate_min: Map.fetch!(params, :hire_rate_min)
      },
      kill_condition: %{
        min_money_gated_candidates: Map.fetch!(params, :min_money_gated_candidates)
      }
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

  defp parse_saved_searches(list) when is_list(list) do
    Enum.map(list, fn entry ->
      case String.split(entry, "|", parts: 2) do
        [source, query] -> %{source: String.trim(source), query: String.trim(query)}
        [single] -> %{source: "upwork", query: String.trim(single)}
      end
    end)
  end

  defp format(%Ecto.Changeset{errors: errors}) do
    Enum.map_join(errors, "; ", fn {f, {msg, _}} -> "#{f}: #{msg}" end)
  end
end
