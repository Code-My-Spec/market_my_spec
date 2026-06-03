defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.ListPostingsForCandidate do
  @moduledoc """
  MCP tool: read the JobPostings that belong to a Candidate, with the
  fields the agent needs for the 3-pass refinement (SetPainDescriptor,
  MergeCandidates, SplitCandidate, LabelCandidate).

  `list_candidates` returns `job_posting_ids` only — the actual posting
  text (title, description, url) isn't on that read surface because
  inlining it would balloon the typical refinement payload. Call this
  tool with a `candidate_id` to drill in.

  Returns embeddings deliberately omitted — those are 1536 floats each
  and the agent never reads them; pain descriptors come from the text,
  not the vector.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :candidate_id, :string, required: true, doc: "Candidate UUID"
  end

  @impl true
  def execute(%{candidate_id: candidate_id}, frame) do
    scope = frame.assigns.current_scope

    case ProblemDiscovery.list_postings_for_candidate(scope, candidate_id) do
      {:ok, postings} ->
        payload = %{postings: Enum.map(postings, &encode/1)}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Candidate not found"), frame}
    end
  end

  defp encode(p) do
    %{
      id: p.id,
      source: p.source,
      source_id: p.source_id,
      title: p.title,
      description: p.description,
      url: p.url,
      total_spent_cents: p.total_spent_cents,
      hire_rate: p.hire_rate,
      pain_descriptor: p.pain_descriptor,
      classification: classification(p.paid_job_signal)
    }
  end

  defp classification(%Ecto.Association.NotLoaded{}), do: nil
  defp classification(nil), do: nil
  defp classification(%{classification: c}), do: to_string(c)
end
