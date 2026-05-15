defmodule MarketMySpec.McpServers.Engagements.Tools.CreateSearch do
  @moduledoc """
  MCP tool that creates a named SavedSearch scoped to the calling account.

  Required: `name` and `query` (a Google-style query string).
  At least one venue selector must be provided — either a non-empty
  `venue_ids` list or a non-empty `source_wildcards` list. Both may be
  given.

  Returns the created search (with linked venues) as JSON, or an error
  response carrying changeset error messages on failure.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements

  schema do
    field :name, :string, required: true, doc: "Saved-search name (unique within account)"
    field :query, :string, required: true, doc: "Google-style query string"
    field :venue_ids, {:list, :integer}, required: false, doc: "Linked Venue ids"

    field :source_wildcards, {:list, :string},
      required: false,
      doc: "Source wildcards: \"reddit\" and/or \"elixirforum\""
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope

    attrs = %{
      name: Map.fetch!(params, :name),
      query: Map.fetch!(params, :query),
      venue_ids: Map.get(params, :venue_ids, []),
      source_wildcards: parse_wildcards(Map.get(params, :source_wildcards, []))
    }

    case Engagements.create_saved_search(scope, attrs) do
      {:ok, search} ->
        payload = %{search: encode_search(search)}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, changeset} ->
        {:reply, Response.tool() |> Response.error(format_changeset(changeset)), frame}
    end
  end

  defp parse_wildcards(list) when is_list(list) do
    Enum.map(list, fn
      "reddit" -> :reddit
      "elixirforum" -> :elixirforum
      atom when is_atom(atom) -> atom
      other -> other
    end)
  end

  defp parse_wildcards(_), do: []

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
    %{
      id: venue.id,
      source: venue.source,
      identifier: venue.identifier
    }
  end

  defp format_changeset(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end
end
