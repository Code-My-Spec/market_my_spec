defmodule MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview do
  @moduledoc """
  MCP tool that orients the agent at the start of a marketing strategy session.

  Returns the full SKILL.md playbook plus a structured step manifest with
  MCP resource URIs for each of the 8 steps. The calling agent should:

  1. Read the orientation to understand the overall flow.
  2. Follow the 8-step sequence — do NOT read all steps upfront.
  3. Fetch each step resource via MCP when it reaches that step.
  4. Write step artifacts as each step completes — don't batch.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.MCP.Error
  alias Anubis.Server.Response
  alias MarketMySpec.Skills

  @steps [
    %{number: 1, slug: "01_current_state", label: "Current state", mode: "Interview"},
    %{number: 2, slug: "02_jobs_and_segments", label: "Jobs & segments", mode: "Interview"},
    %{number: 3, slug: "03_persona_research", label: "Persona research", mode: "Research agents"},
    %{number: 4, slug: "04_beachhead", label: "Beachhead", mode: "Synthesis"},
    %{number: 5, slug: "05_positioning", label: "Positioning", mode: "Synthesis + light research"},
    %{number: 6, slug: "06_messaging", label: "Messaging", mode: "Synthesis"},
    %{number: 7, slug: "07_channels", label: "Channels", mode: "Synthesis + light research"},
    %{number: 8, slug: "08_plan", label: "90-day plan", mode: "Synthesis"}
  ]

  schema do
    field :business_context, :string, required: false, doc: "Optional hint about the user's domain or focus area"
  end

  @impl true
  def execute(_args, frame) do
    case Skills.read_skill_md() do
      {:ok, skill_md} ->
        orientation = build_orientation(skill_md)
        {:reply, Response.tool() |> Response.text(orientation), frame}

      {:error, reason} ->
        {:error, Error.execution("Failed to load skill orientation: #{inspect(reason)}"), frame}
    end
  end

  defp build_orientation(skill_md) do
    step_manifest = build_step_manifest()

    """
    #{skill_md}

    ---

    ## Step manifest — resource URIs

    Fetch each step resource via MCP when you reach it. Do NOT read all steps upfront.

    #{step_manifest}

    ## Agent operating rules

    - Follow the steps sequentially. Orient first (Step 0), then load one step at a time.
    - Interview one or two questions at a time. Never dump a full questionnaire.
    - Write artifacts as you go — don't batch. If the user bails after step 3, they should still have three usable files in their account workspace.
    - Deflect downstream content requests (blog posts, ads, slide decks, analytics setup) — those are out of scope for this skill.
    - Adapt to the business type. Do not default to dev-tool, SaaS, or tech examples unless the user's business is actually one of those.
    """
  end

  defp build_step_manifest do
    @steps
    |> Enum.map(fn step ->
      "| #{step.number} | #{step.label} | #{step.mode} | `marketing-strategy://steps/#{step.slug}` |"
    end)
    |> then(fn rows ->
      header = "| # | Step | Mode | Resource URI |\n|---|---|---|---|"
      Enum.join([header | rows], "\n")
    end)
  end
end
