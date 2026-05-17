defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.ArchiveCustomMetric do
  @moduledoc """
  Archives a custom metric for a Google Analytics 4 property.

  Archives an existing custom metric by its resource name. Archived metrics
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
        "The resource name of the custom metric to archive (e.g., properties/1234/customMetrics/5678)"
    )
  end

  @impl true
  def execute(params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, metric_name} <- validate_metric_name(params.name),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, _result} <- Analytics.archive_custom_metric(conn, metric_name) do
        format_response(metric_name)
      else
        {:error, :invalid_metric_name} ->
          error_response(
            "Invalid custom metric name. Expected format: properties/1234/customMetrics/5678"
          )

        {:error, reason} ->
          error_response("Failed to archive custom metric: #{inspect(reason)}")
      end

    {:reply, response, frame}
  end

  defp validate_metric_name(name) when is_binary(name) do
    # Validate the format: properties/{property_id}/customMetrics/{metric_id}
    case Regex.match?(~r/^properties\/\d+\/customMetrics\/\d+$/, name) do
      true -> {:ok, name}
      false -> {:error, :invalid_metric_name}
    end
  end

  defp validate_metric_name(_), do: {:error, :invalid_metric_name}

  defp format_response(metric_name) do
    Response.tool()
    |> Response.text("""
    Successfully archived custom metric: #{metric_name}

    The custom metric has been archived and is no longer available for use.
    Historical data for this metric is preserved.
    """)
  end

  defp error_response(message) when is_binary(message) do
    Response.tool()
    |> Response.error(message)
  end
end
