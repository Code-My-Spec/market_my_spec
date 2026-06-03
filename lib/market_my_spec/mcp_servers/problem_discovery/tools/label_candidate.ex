defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.LabelCandidate do
  @moduledoc """
  MCP tool: assign a semantic label to a Candidate (pass 3 of the agent's
  3-pass cluster refinement). Path C splits algorithmic grouping (MMS)
  from semantic naming (agent).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :candidate_id, :string, required: true
    field :label, :string, required: true
  end

  @impl true
  def execute(%{candidate_id: candidate_id, label: label}, frame) do
    scope = frame.assigns.current_scope

    case ProblemDiscovery.label_candidate(scope, candidate_id, label) do
      {:ok, candidate} ->
        {:reply,
         Response.tool()
         |> Response.text(Jason.encode!(%{candidate_id: candidate.id, label: candidate.label})),
         frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Candidate not found"), frame}

      {:error, changeset} ->
        {:reply, Response.tool() |> Response.error(inspect(changeset.errors)), frame}
    end
  end
end
