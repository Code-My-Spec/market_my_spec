defmodule MarketMySpec.McpServers.MarketingStrategy.Resources.Step do
  @moduledoc """
  MCP resource exposing individual marketing-strategy step files.

  Each of the 8 steps lives at a URI like:
    marketing-strategy://steps/01_current_state

  The agent fetches the step resource when it reaches that step — not upfront.
  This enforces the progressive-disclosure pattern described in SKILL.md.
  """

  use Anubis.Server.Component,
    type: :resource,
    uri_template: "marketing-strategy://steps/{slug}",
    name: "marketing-strategy-step",
    mime_type: "text/markdown"

  alias Anubis.MCP.Error
  alias Anubis.Server.Response
  alias MarketMySpec.Skills

  @impl true
  def read(%{"params" => %{"slug" => slug}}, frame) when is_binary(slug) do
    relative_path = "steps/#{slug}.md"

    case Skills.read_skill_file(relative_path) do
      {:ok, content} ->
        {:reply, Response.resource() |> Response.text(content), frame}

      {:error, :unsafe_path} ->
        {:error, Error.protocol(:invalid_params, %{slug: slug}), frame}

      {:error, :enoent} ->
        {:error, Error.resource(:not_found, %{uri: "marketing-strategy://steps/#{slug}"}), frame}

      {:error, reason} ->
        {:error, Error.execution("Failed to read step #{slug}: #{inspect(reason)}"), frame}
    end
  end

  def read(_params, frame) do
    {:error, Error.protocol(:invalid_params, %{message: "Step resource requires a slug parameter"}),
     frame}
  end
end
