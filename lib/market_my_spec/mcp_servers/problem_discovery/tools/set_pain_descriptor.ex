defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.SetPainDescriptor do
  @moduledoc """
  MCP tool: write a structured pain_descriptor on a JobPosting describing
  the underlying pain it represents. Pass 1 of the 3-pass cluster
  refinement guided by the problem-discovery skill (per-JobPosting open
  coding; consolidate/split happens in pass 2; LabelCandidate in pass 3).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :job_posting_id, :string, required: true

    field :pain_descriptor, :string,
      required: true,
      max_length: 256,
      doc:
        "≤10 words in the posting's own language; describes the underlying pain. Up to 256 chars."
  end

  @impl true
  def execute(%{job_posting_id: jp_id, pain_descriptor: desc}, frame) do
    scope = frame.assigns.current_scope

    case ProblemDiscovery.set_pain_descriptor(scope, jp_id, desc) do
      {:ok, posting} ->
        {:reply,
         Response.tool()
         |> Response.text(
           Jason.encode!(%{
             job_posting_id: posting.id,
             pain_descriptor: posting.pain_descriptor
           })
         ),
         frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("JobPosting not found"), frame}

      {:error, changeset} ->
        {:reply, Response.tool() |> Response.error(inspect(changeset.errors)), frame}
    end
  end
end
