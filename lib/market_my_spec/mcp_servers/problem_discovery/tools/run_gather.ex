defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather do
  @moduledoc """
  MCP tool: run Gather for a Frame.

  - Default mode (async): spawns the additive per-saved-search Gather
    on `ProblemDiscovery.GatherSupervisor` and returns immediately with
    the saved-search count and a "started" status. The agent polls
    `GetFrame` for `artifacts.JobPosting` to track progress. Per-search
    `gathered_at` marks give free crash resume — if the BEAM dies
    mid-gather, the agent re-runs RunGather and completed searches skip.
  - Probe mode: small-sample Gather against an uncommitted draft Frame
    (criterion 6580). Returns the sample synchronously without persisting.
  - Test mode: `config :market_my_spec, :gather_mode, :sync` forces the
    default path to run inline so spex can assert on results immediately
    (config/test.exs).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :frame_id, :string, required: false, doc: "Committed Frame id (default mode)"
    field :mode, :string, required: false, doc: "\"probe\" or default (committed run)"
    field :limit, :integer, required: false
    field :force, :boolean, required: false

    # Probe-mode draft Frame — flattened to primitives because the agent
    # was hitting Anubis/Peri -32602 on nested :map params. Only used
    # when mode=\"probe\".
    field :description, :string,
      required: false,
      doc: "Probe mode: draft Frame's hypothesis statement"

    field :saved_searches, {:list, :string},
      required: false,
      doc: "Probe mode: list of \"source|query\" strings to sample against"

    field :total_spent_min, :integer,
      required: false,
      doc: "Probe mode: money-gate threshold (paired with :hire_rate_min)"

    field :hire_rate_min, :integer, required: false, doc: "Probe mode: money-gate threshold"

    field :min_money_gated_candidates, :integer,
      required: false,
      doc: "Probe mode: kill-condition threshold"
  end

  @impl true
  def execute(%{mode: "probe"} = params, frame) do
    scope = frame.assigns.current_scope
    draft = build_draft(params)

    case ProblemDiscovery.probe_gather(scope, draft, limit: Map.get(params, :limit, 20)) do
      {:ok, payload} ->
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error(inspect(reason)), frame}
    end
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    frame_id = Map.fetch!(params, :frame_id)
    opts = if Map.get(params, :force), do: [force: true], else: []

    case gather_mode() do
      :sync -> run_sync(scope, frame_id, opts, frame)
      :async -> run_async(scope, frame_id, opts, frame)
    end
  end

  defp gather_mode, do: Application.get_env(:market_my_spec, :gather_mode, :async)

  defp run_sync(scope, frame_id, opts, frame) do
    case ProblemDiscovery.run_gather(scope, frame_id, opts) do
      {:ok, payload} ->
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error(inspect(reason)), frame}
    end
  end

  # Fire-and-forget: confirm the Frame exists + is in scope (so the agent
  # gets a useful error synchronously), then spawn the gather under a
  # supervised Task and return immediately. Crash semantics: completed
  # saved_searches are marked durable in DB; an in-flight search is lost
  # but re-runs cleanly on the agent's next RunGather call.
  defp run_async(scope, frame_id, opts, frame) do
    case ProblemDiscovery.get_frame(scope, frame_id) do
      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Frame not found"), frame}

      {:ok, frame_record} ->
        # Capture the scope into the Task closure since the Task runs
        # outside the MCP request process.
        Task.Supervisor.start_child(
          MarketMySpec.ProblemDiscovery.GatherSupervisor,
          fn -> ProblemDiscovery.run_gather(scope, frame_id, opts) end
        )

        payload = %{
          status: "started",
          frame_id: frame_id,
          saved_search_count: length(frame_record.saved_searches),
          message:
            "Gather running in background. Poll GetFrame for artifacts.JobPosting count to track progress. " <>
              "No durability guarantee — if the BEAM restarts mid-gather, completed saved_searches are " <>
              "marked and skip on a retry; in-flight ones re-run on the next RunGather call (idempotent)."
        }

        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}
    end
  end

  defp build_draft(params) do
    %{
      description: Map.get(params, :description),
      saved_searches: parse_saved_searches(Map.get(params, :saved_searches, [])),
      money_gate: %{
        total_spent_min: Map.get(params, :total_spent_min),
        hire_rate_min: Map.get(params, :hire_rate_min)
      },
      kill_condition: %{
        min_money_gated_candidates: Map.get(params, :min_money_gated_candidates)
      }
    }
  end

  defp parse_saved_searches(list) when is_list(list) do
    Enum.map(list, fn entry ->
      case String.split(entry, "|", parts: 2) do
        [source, query] -> %{source: String.trim(source), query: String.trim(query)}
        [single] -> %{source: "upwork", query: String.trim(single)}
      end
    end)
  end
end
