defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.MergeCandidates do
  @moduledoc """
  MCP tool: merge multiple Candidates into a target. Recomputes the
  target's centroid as mean of combined members; reassigns JobPostings
  and PaidJobSignals; deletes the merged-from Candidates and their
  RedTeamVerdicts.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :candidate_ids, {:list, :string},
      required: true,
      doc: "List of Candidate ids to merge (must include the target)"

    field :target_id, :string, required: true, doc: "The Candidate that survives the merge"
  end

  @impl true
  def execute(%{candidate_ids: ids, target_id: target_id}, frame) do
    scope = frame.assigns.current_scope

    case ProblemDiscovery.merge_candidates(scope, ids, target_id) do
      {:ok, target} ->
        {:reply,
         Response.tool()
         |> Response.text(Jason.encode!(%{target_id: target.id, merged: length(ids)})),
         frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error(inspect(reason)), frame}
    end
  end
end
