defmodule MarketMySpec.McpServers.Engagements.Tools.SearchEngagements do
  @moduledoc """
  MCP tool that searches for engagement opportunities across enabled venues.

  Delegates to `MarketMySpec.Engagements.Search.search/3`, which fans out to
  all enabled venues for the current account in parallel, deduplicates results,
  ranks by venue weight × per-source signal, and returns a unified candidate list.

  Failing sources degrade gracefully — their errors are surfaced in the
  `failures` field of the response envelope without crashing the tool.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.Search

  schema do
    field :query, :string, required: true, doc: "Keyword query to search across venues"
    field :venue, :string, required: false, doc: "Optional venue identifier to scope the search"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    query = params.query
    venue = Map.get(params, :venue)

    opts = if venue, do: [venue: venue], else: []

    %{candidates: candidates, failures: failures} = Search.search(scope, query, opts)

    payload = %{
      candidates: candidates,
      failures: encode_failures(failures)
    }

    response =
      Response.tool()
      |> Response.text(Jason.encode!(payload))

    {:reply, response, frame}
  end

  defp encode_failures(failures) do
    Enum.map(failures, fn
      %{venue: nil, reason: reason} ->
        %{venue: nil, reason: inspect(reason)}

      %{venue: venue, reason: reason} ->
        %{
          venue: %{source: venue.source, identifier: venue.identifier},
          reason: inspect(reason)
        }
    end)
  end
end
