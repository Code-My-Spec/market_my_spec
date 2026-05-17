defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.DeleteKeyEvent do
  @moduledoc """
  Deletes a key event for a Google Analytics 4 property.

  Removes a key event (formerly known as a conversion) from the property.
  Only custom key events can be deleted. Requires the user to have connected
  their Google account via OAuth and have access to the specified property.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Google.Analytics
  alias MarketMySpec.McpServers.Validators

  schema do
    field(:name, :string,
      required: true,
      description:
        "The resource name of the key event to delete (e.g., properties/1234/keyEvents/event_name)"
    )
  end

  @impl true
  def execute(params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, key_event_name} <- validate_key_event_name(params.name),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, _result} <- Analytics.delete_key_event(conn, key_event_name) do
        format_response(key_event_name)
      else
        {:error, :invalid_key_event_name} ->
          error_response(
            "Invalid key event name. Expected format: properties/1234/keyEvents/event_name"
          )

        {:error, reason} ->
          error_response("Failed to delete key event: #{inspect(reason)}")
      end

    {:reply, response, frame}
  end

  defp validate_key_event_name(name) when is_binary(name) do
    # Validate the format: properties/{property_id}/keyEvents/{event_name}
    case Regex.match?(~r/^properties\/\d+\/keyEvents\//, name) do
      true -> {:ok, name}
      false -> {:error, :invalid_key_event_name}
    end
  end

  defp validate_key_event_name(_), do: {:error, :invalid_key_event_name}

  defp format_response(key_event_name) do
    Response.tool()
    |> Response.text("""
    Successfully deleted key event: #{key_event_name}

    The key event has been removed from the property.
    """)
  end

  defp error_response(message) when is_binary(message) do
    Response.tool()
    |> Response.error(message)
  end
end
