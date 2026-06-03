defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster do
  @moduledoc """
  MCP tool: run Cluster for a Frame — one KMeans pass over JobPosting
  embeddings, persisting fresh Candidates with mean-of-members centroids.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :frame_id, :string, required: true
    field :k, :integer, required: false, doc: "Optional pinned K; skips silhouette search"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    frame_id = Map.fetch!(params, :frame_id)
    opts = case Map.get(params, :k) do
      nil -> []
      k when is_integer(k) -> [k: k]
    end

    case ProblemDiscovery.run_cluster(scope, frame_id, opts) do
      {:ok, payload} ->
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error(inspect(reason)), frame}
    end
  end
end
