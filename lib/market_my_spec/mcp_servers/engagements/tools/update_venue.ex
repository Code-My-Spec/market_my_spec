defmodule MarketMySpec.McpServers.Engagements.Tools.UpdateVenue do
  @moduledoc """
  MCP tool that updates an existing Venue scoped to the calling account.

  Accepts a `venue_id` plus any subset of `weight` and `enabled`. Returns
  the updated venue as JSON, or an error response when the venue does not
  belong to the account or the changeset is invalid.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements

  schema do
    field :venue_id, :integer, required: true, doc: "Venue id to update"
    field :weight, :float, required: false, doc: "New ranking weight"
    field :enabled, :boolean, required: false, doc: "Enable or disable the venue"
  end

  @impl true
  def execute(params, frame) do
    scope = frame.assigns.current_scope
    venue_id = Map.fetch!(params, :venue_id)

    attrs = Map.take(params, [:weight, :enabled])

    case Engagements.update_venue(scope, venue_id, attrs) do
      {:ok, venue} ->
        payload = %{venue: encode_venue(venue)}
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Venue not found: #{venue_id}"), frame}

      {:error, changeset} ->
        {:reply, Response.tool() |> Response.error(format_changeset(changeset)), frame}
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
