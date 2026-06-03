defmodule MarketMySpec.McpServers.ProblemDiscovery.Resources.Research do
  @moduledoc """
  MCP resource exposing practitioner-research files that ground each
  phase of the problem-discovery pipeline.

  Eight research files live at URIs like:
    problem-discovery://research/01_money_as_validation
    problem-discovery://research/02_framing_fuzzy_problems
    problem-discovery://research/03_marketplace_signal_extraction
    problem-discovery://research/04_clustering_qualitative_records
    problem-discovery://research/05_red_teaming_candidates
    problem-discovery://research/06_pipeline_anti_patterns
    problem-discovery://research/99_design_critique
    problem-discovery://research/00_index

  Progressive disclosure: the agent loads a research file when entering
  the corresponding phase or when a founder asks "why?" — not upfront.
  SKILL.md and each step file reference research files by relative path
  so the agent knows what to fetch.
  """

  use Anubis.Server.Component,
    type: :resource,
    uri_template: "problem-discovery://research/{slug}",
    name: "problem-discovery-research",
    mime_type: "text/markdown"

  alias Anubis.MCP.Error
  alias Anubis.Server.Response
  alias MarketMySpec.Skills.ProblemDiscovery

  @impl true
  def read(%{"params" => %{"slug" => slug}}, frame) when is_binary(slug) do
    relative_path = "research/#{slug}.md"

    case ProblemDiscovery.read_skill_file(relative_path) do
      {:ok, content} ->
        {:reply, Response.resource() |> Response.text(content), frame}

      {:error, :unsafe_path} ->
        {:error, Error.protocol(:invalid_params, %{slug: slug}), frame}

      {:error, :enoent} ->
        {:error,
         Error.resource(:not_found, %{uri: "problem-discovery://research/#{slug}"}), frame}

      {:error, reason} ->
        {:error, Error.execution("Failed to read research file #{slug}: #{inspect(reason)}"),
         frame}
    end
  end

  def read(_params, frame) do
    {:error,
     Error.protocol(:invalid_params, %{message: "Research resource requires a slug parameter"}),
     frame}
  end
end
