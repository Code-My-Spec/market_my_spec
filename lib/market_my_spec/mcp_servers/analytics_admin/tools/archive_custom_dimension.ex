defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.ArchiveCustomDimension do
  @moduledoc """
  Archives a custom dimension for a Google Analytics 4 property.

  Archives an existing custom dimension by its resource name. Archived dimensions
  are no longer available for use but their historical data is preserved. Requires
  the user to have connected their Google account via OAuth and have access to the
  specified property.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Google.Analytics
  alias MarketMySpec.McpServers.Validators

  schema do
    field(:name, :string,
      required: true,
      description:
        "The resource name of the custom dimension to archive (e.g., properties/1234/customDimensions/5678)"
    )
  end

  @impl true
  def execute(params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, dimension_name} <- validate_dimension_name(params.name),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, _result} <- Analytics.archive_custom_dimension(conn, dimension_name) do
        format_response(dimension_name)
      else
        {:error, :invalid_dimension_name} ->
          error_response(
            "Invalid custom dimension name. Expected format: properties/1234/customDimensions/5678"
          )

        {:error, reason} ->
          error_response("Failed to archive custom dimension: #{inspect(reason)}")
      end

    {:reply, response, frame}
  end

  defp validate_dimension_name(name) when is_binary(name) do
    # Validate the format: properties/{property_id}/customDimensions/{dimension_id}
    case Regex.match?(~r/^properties\/\d+\/customDimensions\/\d+$/, name) do
      true -> {:ok, name}
      false -> {:error, :invalid_dimension_name}
    end
  end

  defp validate_dimension_name(_), do: {:error, :invalid_dimension_name}

  defp format_response(dimension_name) do
    Response.tool()
    |> Response.text("""
    Successfully archived custom dimension: #{dimension_name}

    The custom dimension has been archived and is no longer available for use.
    Historical data for this dimension is preserved.
    """)
  end

  defp error_response(message) when is_binary(message) do
    Response.tool()
    |> Response.error(message)
  end
end
