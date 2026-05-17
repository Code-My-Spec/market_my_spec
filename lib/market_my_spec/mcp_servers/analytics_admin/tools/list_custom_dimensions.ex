defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.ListCustomDimensions do
  @moduledoc """
  Lists custom dimensions for a Google Analytics 4 property.

  Returns information about custom dimensions including names, display names,
  parameter names, and scope. Requires the user to have connected their Google
  account via OAuth and have access to the specified property.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Google.Analytics
  alias MarketMySpec.McpServers.Validators

  schema do
  end

  @impl true
  def execute(_params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, property_id} <- get_property_id(scope),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, result} <- Analytics.list_custom_dimensions(conn, "properties/#{property_id}") do
        format_response(result)
      else
        {:error, :missing_property_id} ->
          error_response(
            "Google Analytics Property ID is not set for this account. Set google_analytics_property_id on the active account."
          )

        {:error, reason} ->
          error_response("Failed to list custom dimensions: #{inspect(reason)}")
      end

    {:reply, response, frame}
  end

  defp get_property_id(scope) do
    case scope.active_account.google_analytics_property_id do
      nil -> {:error, :missing_property_id}
      "" -> {:error, :missing_property_id}
      property_id -> {:ok, property_id}
    end
  end

  defp format_response(%{customDimensions: [_ | _] = dimensions}) do
    Response.tool()
    |> Response.text(format_dimensions(dimensions))
  end

  defp format_response(_response) do
    Response.tool()
    |> Response.text("No custom dimensions found for this property.")
  end

  defp format_dimensions(dimensions) do
    Enum.map_join(dimensions, "\n", fn dimension ->
      """
      Custom Dimension: #{dimension.displayName || "Unnamed"}
      - Name: #{dimension.name}
      - Parameter Name: #{dimension.parameterName}
      - Scope: #{dimension.scope || "N/A"}
      - Description: #{dimension.description || "No description"}
      """
    end)
  end

  defp error_response(message) when is_binary(message) do
    Response.tool()
    |> Response.error(message)
  end
end
