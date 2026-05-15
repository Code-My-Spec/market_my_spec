defmodule MarketMySpec.McpServers.Engagements.Tools.ListVenues do
  @moduledoc """
  MCP tool that lists every Venue scoped to the calling account.

  Pass an optional `source` (`"reddit"` or `"elixirforum"`) to filter to
  one platform. The response payload carries a `venues` list with each
  venue's id, source, identifier, weight, and enabled flag.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements

  schema do
    field :source, :string, required: false, doc: "Optional source filter: \"reddit\" or \"elixirforum\""
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    source = parse_source(Map.get(params, :source))

    venues = Engagements.list_venues(scope, source)
    payload = %{venues: Enum.map(venues, &encode_venue/1)}

    {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}
  end

  defp parse_source(nil), do: nil
  defp parse_source("reddit"), do: :reddit
  defp parse_source("elixirforum"), do: :elixirforum
  defp parse_source(other) when is_atom(other), do: other
  defp parse_source(_), do: nil

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
