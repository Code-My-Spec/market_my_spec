defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates do
  @moduledoc """
  MCP tool: list Candidates for a Frame with label, score, member-posting
  count, gated-in count, and verdict status. The agent's read surface for
  the labeling/refinement loop and Red-team selection.
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

    case ProblemDiscovery.list_candidates(scope, frame_id) do
      {:ok, candidates} ->
        payload = %{candidates: Enum.map(candidates, &encode/1)}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Frame not found"), frame}
    end
  end

  # Embeddings and centroids deliberately omitted — they're 1536 floats
  # each (a single full list_candidates payload was ~5MB of vector data),
  # and the agent never reads them: refinement uses labels, scores, gated
  # counts, and the postings themselves (via list_postings_for_candidate).
  # The mean-of-members invariant is a Pipeline.Cluster correctness
  # property, not an agent contract — assert it from the test layer
  # via Repo, not via the MCP read surface.
  defp encode(c) do
    %{
      id: c.id,
      label: c.label,
      score: c.score,
      member_count: length(c.job_postings || []),
      gated_in_count: gated_in_count(c.paid_job_signals),
      verdict: verdict(c.red_team_verdict),
      job_posting_ids: Enum.map(c.job_postings || [], & &1.id),
      inserted_at: c.inserted_at
    }
  end

  defp gated_in_count(%Ecto.Association.NotLoaded{}), do: 0
  defp gated_in_count(signals) when is_list(signals),
    do: Enum.count(signals, &(&1.classification == :gated_in))
  defp gated_in_count(_), do: 0

  defp verdict(nil), do: nil
  defp verdict(%Ecto.Association.NotLoaded{}), do: nil
  defp verdict(%{verdict: v}), do: v
end
