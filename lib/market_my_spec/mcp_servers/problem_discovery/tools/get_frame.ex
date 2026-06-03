defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame do
  @moduledoc """
  MCP tool: fetch a single Frame's attributes plus per-stage artifact
  counts (JobPostings, Candidates, PaidJobSignals, RedTeamVerdicts).
  """

  use Anubis.Server.Component, type: :tool

  import Ecto.Query

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery
  alias MarketMySpec.ProblemDiscovery.Board
  alias MarketMySpec.ProblemDiscovery.Candidate
  alias MarketMySpec.ProblemDiscovery.JobPosting
  alias MarketMySpec.ProblemDiscovery.PaidJobSignal
  alias MarketMySpec.ProblemDiscovery.RedTeamVerdict
  alias MarketMySpec.Repo

  schema do
    field :frame_id, :string, required: true
  end

  @impl true
  def execute(%{frame_id: frame_id}, frame) do
    scope = frame.assigns.current_scope

    case ProblemDiscovery.get_frame(scope, frame_id) do
      {:ok, f} ->
        {:reply, Response.tool() |> Response.text(Jason.encode!(encode(f))), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Frame not found"), frame}
    end
  end

  defp encode(f) do
    job_posting_count = count(JobPosting, :frame_id, f.id)
    candidate_count = count(Candidate, :frame_id, f.id)
    paid_job_signal_count = count_paid_job_signals(f.id)
    red_team_verdict_count = count_red_team_verdicts(f.id)
    board_count = board_count(f.id)

    %{
      id: f.id,
      description: f.description,
      saved_searches: f.saved_searches,
      money_gate: f.money_gate,
      kill_condition: f.kill_condition,
      artifacts: %{
        JobPosting: job_posting_count,
        Candidate: candidate_count,
        PaidJobSignal: paid_job_signal_count,
        RedTeamVerdict: red_team_verdict_count,
        Board: board_count
      },
      artifact_creation_order: creation_order(f.id, board_count)
    }
  end

  defp count(schema, field, value) do
    Repo.aggregate(from(s in schema, where: field(s, ^field) == ^value), :count)
  end

  defp count_paid_job_signals(frame_id) do
    Repo.aggregate(
      from(pjs in PaidJobSignal,
        join: c in Candidate,
        on: pjs.candidate_id == c.id,
        where: c.frame_id == ^frame_id
      ),
      :count
    )
  end

  defp count_red_team_verdicts(frame_id) do
    Repo.aggregate(
      from(rtv in RedTeamVerdict,
        join: c in Candidate,
        on: rtv.candidate_id == c.id,
        where: c.frame_id == ^frame_id
      ),
      :count
    )
  end

  # Board is a projection assembled on demand; "1" means the projection
  # can be built for this Frame (it has the prerequisite artifacts) — the
  # board exists as an observable typed view.
  defp board_count(frame_id) do
    case Board.assemble(frame_id) do
      {:ok, %{candidates: [_ | _]}} -> 1
      _ -> 0
    end
  end

  # Ordered list of artifact kinds in pipeline order. Each kind is included
  # only if it has a nonzero count, and ordering follows the canonical
  # pipeline sequence (Gather → Cluster → Score → Red-team → Board).
  defp creation_order(frame_id, board_count) do
    [
      {"JobPosting", min_inserted_at(JobPosting, :frame_id, frame_id)},
      {"Candidate", min_inserted_at(Candidate, :frame_id, frame_id)},
      {"PaidJobSignal", min_paid_job_signal_inserted_at(frame_id)},
      {"RedTeamVerdict", min_red_team_verdict_inserted_at(frame_id)},
      {"Board", if(board_count > 0, do: DateTime.utc_now(), else: nil)}
    ]
    |> Enum.reject(fn {_kind, ts} -> is_nil(ts) end)
    |> Enum.map(fn {kind, _ts} -> kind end)
  end

  defp min_inserted_at(schema, field, value) do
    Repo.aggregate(from(s in schema, where: field(s, ^field) == ^value), :min, :inserted_at)
  end

  defp min_paid_job_signal_inserted_at(frame_id) do
    Repo.aggregate(
      from(pjs in PaidJobSignal,
        join: c in Candidate,
        on: pjs.candidate_id == c.id,
        where: c.frame_id == ^frame_id
      ),
      :min,
      :inserted_at
    )
  end

  defp min_red_team_verdict_inserted_at(frame_id) do
    Repo.aggregate(
      from(rtv in RedTeamVerdict,
        join: c in Candidate,
        on: rtv.candidate_id == c.id,
        where: c.frame_id == ^frame_id
      ),
      :min,
      :inserted_at
    )
  end
end
