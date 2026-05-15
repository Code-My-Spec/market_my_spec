defmodule MarketMySpec.McpServers.Engagements.Tools.RemoveVenue do
  @moduledoc """
  MCP tool that deletes a Venue scoped to the calling account.

  Returns the removed venue as JSON, or an error response when the venue
  does not exist or belongs to a different account. Account scoping is
  enforced inside `Engagements.delete_venue/2`.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements

  schema do
    field :venue_id, :integer, required: true, doc: "Venue id to remove"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    venue_id = Map.fetch!(params, :venue_id)

    case Engagements.delete_venue(scope, venue_id) do
      {:ok, venue} ->
        payload = %{venue: encode_venue(venue)}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Venue not found: #{venue_id}"), frame}
    end
  end

  defp encode_venue(venue) do
    %{
      id: venue.id,
      source: venue.source,
      identifier: venue.identifier,
      weight: venue.weight,
      enabled: venue.enabled
    }
  end
end
