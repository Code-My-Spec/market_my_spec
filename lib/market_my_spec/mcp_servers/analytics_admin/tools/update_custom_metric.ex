defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.UpdateCustomMetric do
  @moduledoc """
  Updates a custom metric for a Google Analytics 4 property.

  Updates specific fields of a custom metric. The update_mask parameter specifies
  which fields should be updated. Use "*" to update all fields. Requires the user
  to have connected their Google account via OAuth and have access to the specified property.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Google.Analytics
  alias MarketMySpec.McpServers.Validators

  schema do
    field(:name, :string,
      required: true,
      description:
        "The resource name of the custom metric (e.g., properties/1234/customMetrics/5678)"
    )

    field(:display_name, :string,
      required: false,
      description: "Display name for the custom metric"
    )

    field(:description, :string, required: false, description: "Description of the custom metric")

    field(:measurement_unit, :string,
      required: false,
      description:
        "Measurement unit: STANDARD, CURRENCY, FEET, METERS, KILOMETERS, MILES, MILLISECONDS, SECONDS, MINUTES, HOURS. When updating to CURRENCY, also provide restricted_metric_type"
    )

    field(:restricted_metric_type, :string,
      required: false,
      description:
        "Restricted metric type (only valid for CURRENCY metrics). Valid values: COST_DATA or REVENUE_DATA"
    )

    field(:update_mask, :string,
      required: true,
      description:
        "Comma-separated list of fields to update (e.g., 'displayName,description') or '*' for all fields"
    )
  end

  @valid_measurement_units [
    "STANDARD",
    "CURRENCY",
    "FEET",
    "METERS",
    "KILOMETERS",
    "MILES",
    "MILLISECONDS",
    "SECONDS",
    "MINUTES",
    "HOURS"
  ]

  @impl true
  def execute(params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, metric_name} <- validate_metric_name(params.name),
           {:ok, validated_params} <- validate_params(params),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, result} <-
             Analytics.update_custom_metric(
               conn,
               metric_name,
               validated_params,
               params.update_mask
             ) do
        format_response(result)
      else
        {:error, :invalid_metric_name} ->
          error_response(
            "Invalid custom metric name. Expected format: properties/1234/customMetrics/5678"
          )

        {:error, :invalid_measurement_unit, unit} ->
          error_response(
            "Invalid measurement unit '#{unit}'. Must be one of: #{Enum.join(@valid_measurement_units, ", ")}"
          )

        {:error, :currency_requires_restricted_metric_type} ->
          error_response(
            "When updating measurement_unit to CURRENCY, you must also provide restricted_metric_type. Valid values: COST_DATA or REVENUE_DATA"
          )

        {:error, :invalid_restricted_metric_type, type} ->
          error_response(
            "Invalid restricted_metric_type '#{type}'. Valid values: COST_DATA or REVENUE_DATA"
          )

        {:error, :no_fields_to_update} ->
          error_response(
            "No fields specified for update. Please provide at least one field to update."
          )

        {:error, reason} ->
          error_response("Failed to update custom metric: #{inspect(reason)}")
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

  defp validate_params(params) do
    measurement_unit = params[:measurement_unit]
    restricted_type = params[:restricted_metric_type]

    # Validate measurement unit if provided
    cond do
      measurement_unit && measurement_unit not in @valid_measurement_units ->
        {:error, :invalid_measurement_unit, measurement_unit}

      # If updating to CURRENCY, require restricted_metric_type
      measurement_unit == "CURRENCY" && !restricted_type ->
        {:error, :currency_requires_restricted_metric_type}

      # Validate the restricted_metric_type value
      restricted_type && restricted_type not in ["COST_DATA", "REVENUE_DATA"] ->
        {:error, :invalid_restricted_metric_type, restricted_type}

      true ->
        # Build the custom metric map with only the fields that are being updated
        custom_metric = %{}

        custom_metric =
          if params[:display_name] do
            Map.put(custom_metric, :displayName, params.display_name)
          else
            custom_metric
          end

        custom_metric =
          if params[:description] do
            Map.put(custom_metric, :description, params.description)
          else
            custom_metric
          end

        custom_metric =
          if measurement_unit do
            Map.put(custom_metric, :measurementUnit, measurement_unit)
          else
            custom_metric
          end

        custom_metric =
          if restricted_type do
            # Convert single string to array for API
            Map.put(custom_metric, :restrictedMetricType, [restricted_type])
          else
            custom_metric
          end

        if map_size(custom_metric) == 0 and params.update_mask != "*" do
          {:error, :no_fields_to_update}
        else
          {:ok, custom_metric}
        end
    end
  end

  defp format_response(metric) do
    restricted_type =
      if metric.restrictedMetricType do
        Enum.join(metric.restrictedMetricType, ", ")
      else
        "N/A"
      end

    Response.tool()
    |> Response.text("""
    Successfully updated custom metric:

    Custom Metric: #{metric.displayName || "Unnamed"}
    - Name: #{metric.name}
    - Parameter Name: #{metric.parameterName}
    - Measurement Unit: #{metric.measurementUnit || "N/A"}
    - Scope: #{metric.scope || "N/A"}
    - Description: #{metric.description || "No description"}
    - Restricted Metric Type: #{restricted_type}
    """)
  end

  defp error_response(message) when is_binary(message) do
    Response.tool()
    |> Response.error(message)
  end
end
