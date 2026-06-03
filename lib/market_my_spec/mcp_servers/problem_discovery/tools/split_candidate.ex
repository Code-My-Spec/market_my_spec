defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.SplitCandidate do
  @moduledoc """
  MCP tool: split a Candidate into multiple by partitioning its member
  JobPostings. The original Candidate (and its RedTeamVerdict, since the
  partition shape changed) is deleted.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :candidate_id, :string, required: true

    field :partition, {:list, {:list, :string}},
      required: true,
      doc: "List of lists of JobPosting ids; each inner list becomes one new Candidate"
  end

  @impl true
  def execute(%{candidate_id: candidate_id, partition: partition}, frame) do
    scope = frame.assigns.current_scope

    case ProblemDiscovery.split_candidate(scope, candidate_id, partition) do
      {:ok, new_candidates} ->
        {:reply,
         Response.tool()
         |> Response.text(
           Jason.encode!(%{
             new_candidate_ids: Enum.map(new_candidates, & &1.id),
             count: length(new_candidates)
           })
         ),
         frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error(inspect(reason)), frame}
    end
  end
end
