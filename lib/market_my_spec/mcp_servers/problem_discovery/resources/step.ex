defmodule MarketMySpec.McpServers.ProblemDiscovery.Resources.Step do
  @moduledoc """
  MCP resource exposing individual problem-discovery step files.

  Six steps live at URIs like:
    problem-discovery://steps/01_frame
    problem-discovery://steps/02_gather
    problem-discovery://steps/03_cluster
    problem-discovery://steps/04_score
    problem-discovery://steps/05_redteam
    problem-discovery://steps/06_board

  The agent fetches the step resource when it enters that phase — not
  upfront. This enforces the progressive-disclosure pattern documented
  in SKILL.md.
  """

  use Anubis.Server.Component,
    type: :resource,
    uri_template: "problem-discovery://steps/{slug}",
    name: "problem-discovery-step",
    mime_type: "text/markdown"

  alias Anubis.MCP.Error
  alias Anubis.Server.Response
  alias MarketMySpec.Skills.ProblemDiscovery

  @impl true
  def read(%{"params" => %{"slug" => slug}}, frame) when is_binary(slug) do
    relative_path = "steps/#{slug}.md"

    case ProblemDiscovery.read_skill_file(relative_path) do
      {:ok, content} ->
        {:reply, Response.resource() |> Response.text(content), frame}

      {:error, :unsafe_path} ->
        {:error, Error.protocol(:invalid_params, %{slug: slug}), frame}

      {:error, :enoent} ->
        {:error,
         Error.resource(:not_found, %{uri: "problem-discovery://steps/#{slug}"}), frame}

      {:error, reason} ->
        {:error, Error.execution("Failed to read step #{slug}: #{inspect(reason)}"), frame}
    end
  end

  def read(_params, frame) do
    {:error,
     Error.protocol(:invalid_params, %{message: "Step resource requires a slug parameter"}),
     frame}
  end
end
