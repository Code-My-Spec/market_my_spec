defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.GetBoard do
  @moduledoc """
  MCP tool: fetch the assembled Board view for a Frame — Candidates with
  their final verdict (RedTeamVerdict overrides Score's verdict), the
  Frame's threshold values, the corpus_health header, and the
  kill_condition status (met / not met).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :frame_id, :string, required: true
  end

  @impl true
  def execute(%{frame_id: frame_id}, frame) do
    scope = frame.assigns.current_scope

    case ProblemDiscovery.get_board(scope, frame_id) do
      {:ok, view} ->
        {:reply, Response.tool() |> Response.text(Jason.encode!(encode(view))), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Frame not found"), frame}
    end
  end

  defp encode(view) do
    %{
      frame: %{
        id: view.frame.id,
        title: view.frame.title,
        description: view.frame.description,
        money_gate: view.frame.money_gate,
        kill_condition: view.frame.kill_condition
      },
      corpus_health: view.corpus_health,
      awaiting_redteam: view.awaiting_redteam,
      kill_condition_status: view.kill_condition_status,
      candidates: Enum.map(view.candidates, &encode_candidate/1),
      # Score-survivors that haven't been red-teamed yet. The agent
      # should call RedTeamCandidate on each (one at a time per the skill)
      # to move them from `pending_candidates` into `candidates`. Same
      # shape as the rendered ones minus verdict/kill_argument/cheapest_kill_test.
      pending_candidates: Enum.map(view.pending_candidates, &encode_candidate/1)
    }
  end

  defp encode_candidate(c) do
    %{
      id: c.id,
      label: c.label,
      score: c.score,
      verdict: verdict(c.red_team_verdict),
      kill_argument: kill_argument(c.red_team_verdict),
      cheapest_kill_test: cheapest_kill_test(c.red_team_verdict),
      verification_links:
        c.job_postings
        |> Enum.map(& &1.url)
        |> Enum.reject(&is_nil/1)
    }
  end

  defp verdict(nil), do: nil
  defp verdict(%{verdict: v}), do: v

  defp kill_argument(nil), do: nil
  defp kill_argument(%{kill_argument: ka}), do: ka

  defp cheapest_kill_test(nil), do: nil
  defp cheapest_kill_test(%{cheapest_kill_test: t}), do: t
end
