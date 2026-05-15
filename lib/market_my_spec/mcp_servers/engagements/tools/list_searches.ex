defmodule MarketMySpec.McpServers.Engagements.Tools.ListSearches do
  @moduledoc """
  MCP tool that lists every SavedSearch on the calling account, preloaded
  with linked venues. The response payload carries a `searches` list with
  each search's id, name, query, source_wildcards, and venue summaries.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements

  schema do
  end

  @impl true
  def execute(_params, frame) do
    scope = frame.assigns.current_scope
    searches = Engagements.list_saved_searches(scope)
    payload = %{searches: Enum.map(searches, &encode_search/1)}

    {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}
  end

  defp encode_search(search) do
    %{
      id: search.id,
      name: search.name,
      query: search.query,
      source_wildcards: search.source_wildcards || [],
      venues: encode_venues(search.venues)
    }
  end

  defp encode_venues(%Ecto.Association.NotLoaded{}), do: []
  defp encode_venues(venues) when is_list(venues), do: Enum.map(venues, &encode_venue/1)
  defp encode_venues(_), do: []

  defp encode_venue(venue) do
    %{id: venue.id, source: venue.source, identifier: venue.identifier}
  end
end
