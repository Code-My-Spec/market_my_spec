defmodule MarketMySpec.McpServers.ProblemDiscovery.Resources.SkillOrientation do
  @moduledoc """
  MCP resource exposing the problem-discovery SKILL.md orientation.

  The agent loads this first to learn the 5-stage pipeline, the per-phase
  MCP tools, the founder-direct vs skill-driven surface map, and the
  progressive-disclosure file layout (per `problem-discovery-skill.md`).
  Step files and research files are loaded on demand via Step and
  Research resources respectively.
  """

  use Anubis.Server.Component,
    type: :resource,
    uri: "problem-discovery://orientation",
    name: "problem-discovery-skill-orientation",
    mime_type: "text/markdown"

  alias Anubis.MCP.Error
  alias Anubis.Server.Response
  alias MarketMySpec.Skills.ProblemDiscovery

  @impl true
  def read(_params, frame) do
    case ProblemDiscovery.read_skill_md() do
      {:ok, content} ->
        {:reply, Response.resource() |> Response.text(content), frame}

      {:error, reason} ->
        {:error, Error.execution("Failed to read skill orientation: #{inspect(reason)}"), frame}
    end
  end
end
