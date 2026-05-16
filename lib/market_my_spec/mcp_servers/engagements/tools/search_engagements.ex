defmodule MarketMySpec.McpServers.Engagements.Tools.SearchEngagements do
  @moduledoc """
  MCP tool that searches for engagement opportunities across enabled venues.

  Delegates to `MarketMySpec.Engagements.Search.search/3`, which fans out to
  all enabled venues for the current account in parallel, deduplicates results,
  ranks by venue weight × per-source signal, and returns a unified candidate list.

  Failing sources degrade gracefully — their errors are surfaced in the
  `failures` field of the response envelope without crashing the tool.

  Pass `cursor` (returned as `next_cursor` from a prior call) to fetch the
  next page of results.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.Search

  schema do
    field :query, :string, required: true, doc: "Keyword query to search across venues"
    field :venue, :string, required: false, doc: "Optional venue identifier to scope the search"
    field :cursor, :string, required: false, doc: "Pagination cursor from a prior call"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    query = params.query

    opts = []
    opts = if Map.has_key?(params, :venue), do: [{:venue, params.venue} | opts], else: opts
    opts = if Map.has_key?(params, :cursor), do: [{:cursor, params.cursor} | opts], else: opts

    %{candidates: candidates, failures: failures, next_cursor: next_cursor} =
      Search.search(scope, query, opts)

    payload = %{
      candidates: candidates,
      failures: encode_failures(failures),
      next_cursor: next_cursor
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
