defmodule MarketMySpec.McpServers.MarketingStrategy.Resources.SkillOrientation do
  @moduledoc """
  MCP resource exposing the marketing-strategy SKILL.md orientation document.

  Loaded by the agent at session start to understand the skill's structure
  and the 8-step interview flow. Story 675 will build on this with
  progressive disclosure of individual step prompts.
  """

  use Anubis.Server.Component,
    type: :resource,
    uri: "marketing-strategy://orientation",
    name: "skill-orientation",
    mime_type: "text/markdown"

  alias Anubis.MCP.Error
  alias Anubis.Server.Response
  alias MarketMySpec.Skills

  @impl true
  def read(_params, frame) do
    case Skills.read_skill_md() do
      {:ok, content} ->
        {:reply, Response.resource() |> Response.text(content), frame}

      {:error, reason} ->
        {:error, Error.execution("Failed to read skill orientation: #{inspect(reason)}"), frame}
    end
  end
end
