defmodule MarketMySpec.McpServers.ProblemDiscovery.Tools.RedTeamCandidate do
  @moduledoc """
  MCP tool: prosecute one Candidate (story 741). Conversational with the
  agent, one at a time. Writes or overwrites the RedTeamVerdict for the
  Candidate. The verdict beats Score's mechanical classification on the
  Board (overwrite semantics per `problem-discovery-skill.md`).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.ProblemDiscovery

  schema do
    field :candidate_id, :string, required: true

    field :verdict, :string,
      required: true,
      doc: "\"keep_productizable\" | \"keep_service_only\" | \"watch\" | \"kill\""

    field :kill_argument, :string,
      required: true,
      doc: "Past-tense Klein pre-mortem: \"this bet failed because...\""

    field :cheapest_kill_test, :string,
      required: true,
      doc: "The single cheapest experiment that would confirm or kill this verdict"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope

    attrs = %{
      verdict: parse_verdict(Map.fetch!(params, :verdict)),
      kill_argument: Map.fetch!(params, :kill_argument),
      cheapest_kill_test: Map.fetch!(params, :cheapest_kill_test)
    }

    case ProblemDiscovery.red_team_candidate(scope, Map.fetch!(params, :candidate_id), attrs) do
      {:ok, verdict} ->
        {:reply,
         Response.tool()
         |> Response.text(
           Jason.encode!(%{
             candidate_id: verdict.candidate_id,
             verdict: verdict.verdict
           })
         ),
         frame}

      {:error, reason} ->
        {:reply, Response.tool() |> Response.error(inspect(reason)), frame}
    end
  end

  defp parse_verdict("keep_productizable"), do: :keep_productizable
  defp parse_verdict("keep_service_only"), do: :keep_service_only
  defp parse_verdict("watch"), do: :watch
  defp parse_verdict("kill"), do: :kill
  defp parse_verdict(other), do: other
end
