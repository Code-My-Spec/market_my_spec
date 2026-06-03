defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.RunScore do
  @moduledoc """
  MCP tool: run Score for a Frame — apply the money_gate to each
  JobPosting, write or reclassify PaidJobSignal in place, recompute
  per-Candidate scores. Makes no HTTP requests.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :frame_id, :string, required: true
  end

  @impl true
  def execute(%{frame_id: frame_id}, frame) do
    scope = frame.assigns.current_scope

    case ProblemDiscovery.run_score(scope, frame_id) do
      {:ok, payload} ->
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error(inspect(reason)), frame}
    end
  end
end
