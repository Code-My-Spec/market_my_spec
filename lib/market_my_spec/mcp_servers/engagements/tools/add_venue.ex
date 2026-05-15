defmodule MarketMySpec.McpServers.Engagements.Tools.AddVenue do
  @moduledoc """
  MCP tool that creates a new Venue scoped to the calling account.

  Source must be `"reddit"` or `"elixirforum"`. Identifier is a subreddit
  name (Reddit) or category slug (ElixirForum); the underlying changeset
  validates the format against the appropriate source adapter.

  Returns the created venue as JSON on success, or an error response with
  the changeset error messages on failure.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements

  schema do
    field :source, :string, required: true, doc: "Source platform: \"reddit\" or \"elixirforum\""
    field :identifier, :string, required: true, doc: "Subreddit name or forum category slug"
    field :weight, :float, required: false, doc: "Ranking weight; defaults to 1.0"
    field :enabled, :boolean, required: false, doc: "Defaults to true"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope

    attrs =
      params
      |> Map.take([:source, :identifier, :weight, :enabled])
      |> normalize_source()

    case Engagements.create_venue(scope, attrs) do
      {:ok, venue} ->
        payload = %{venue: encode_venue(venue)}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, changeset} ->
        {:reply, Response.tool() |> Response.error(format_changeset(changeset)), frame}
    end
  end

  defp normalize_source(%{source: source} = attrs) when is_binary(source) do
    case source do
      "reddit" -> %{attrs | source: :reddit}
      "elixirforum" -> %{attrs | source: :elixirforum}
      _ -> attrs
    end
  end

  defp normalize_source(attrs), do: attrs

  defp encode_venue(venue) do
    %{
      id: venue.id,
      source: venue.source,
      identifier: venue.identifier,
      weight: venue.weight,
      enabled: venue.enabled
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
