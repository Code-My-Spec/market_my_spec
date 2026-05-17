defmodule MarketMySpec.McpServers.Engagements.Tools.RunSearch do
  @moduledoc """
  MCP tool that runs a SavedSearch by id and returns the candidates +
  failures envelope from the shared search orchestrator.

  No run history is persisted — saved searches are recipes only. The
  envelope shape matches the ad-hoc `search_engagements` tool so the agent
  can treat both surfaces interchangeably.

  Cross-account access (search_id belongs to a different account) returns
  an error response without leaking candidate data.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements

  schema do
    field :search_id, :integer, required: true, doc: "SavedSearch id to run"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    search_id = Map.fetch!(params, :search_id)

    case Engagements.run_saved_search(scope, search_id) do
      {:ok, %{candidates: candidates, failures: failures}} ->
        payload = %{candidates: candidates, failures: encode_failures(failures)}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Saved search not found: #{search_id}"), frame}
    end
  end

  defp encode_failures(failures) do
    Enum.map(failures, fn failure ->
      %{
        source: failure |> Map.get(:source) |> stringify(),
        venue_identifier: Map.get(failure, :venue_identifier),
        reason: failure |> Map.get(:reason, "") |> stringify_reason()
      }
    end)
  end

  defp stringify(nil), do: nil
  defp stringify(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp stringify(other), do: to_string(other)

  defp stringify_reason(reason) when is_binary(reason), do: reason
  defp stringify_reason(reason), do: inspect(reason)
end
