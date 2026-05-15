defmodule MarketMySpec.McpServers.Engagements.Tools.UpdateSearch do
  @moduledoc """
  MCP tool that updates an existing SavedSearch scoped to the calling
  account.

  Pass any subset of `name`, `query`, `venue_ids`, or `source_wildcards`.
  When `venue_ids` is supplied, the join rows are replaced atomically with
  ownership re-validated; when omitted, the existing venue selection is
  preserved.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements

  schema do
    field :search_id, :integer, required: true, doc: "SavedSearch id to update"
    field :name, :string, required: false, doc: "New name (unique within account)"
    field :query, :string, required: false, doc: "New Google-style query string"
    field :venue_ids, {:list, :integer}, required: false, doc: "Replacement set of Venue ids"

    field :source_wildcards, {:list, :string},
      required: false,
      doc: "Replacement source wildcards: \"reddit\" and/or \"elixirforum\""
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    search_id = Map.fetch!(params, :search_id)

    attrs =
      params
      |> Map.take([:name, :query, :venue_ids, :source_wildcards])
      |> Map.delete(:search_id)
      |> maybe_parse_wildcards()

    case Engagements.update_saved_search(scope, search_id, attrs) do
      {:ok, search} ->
        payload = %{search: encode_search(search)}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Saved search not found: #{search_id}"), frame}

      {:error, changeset} ->
        {:reply, Response.tool() |> Response.error(format_changeset(changeset)), frame}
    end
  end

  defp maybe_parse_wildcards(%{source_wildcards: list} = attrs) when is_list(list) do
    %{
      attrs
      | source_wildcards:
          Enum.map(list, fn
            "reddit" -> :reddit
            "elixirforum" -> :elixirforum
            atom when is_atom(atom) -> atom
            other -> other
          end)
    }
  end

  defp maybe_parse_wildcards(attrs), do: attrs

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
