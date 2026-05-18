defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.CreateCustomMetric do
  @moduledoc """
  Creates a custom metric for a Google Analytics 4 property.

  Allows creating new custom metrics with a display name, parameter name,
  measurement unit, scope (EVENT), and optional description. When using CURRENCY
  as the measurement unit, you must also provide restricted_metric_type
  (either "COST_DATA" or "REVENUE_DATA"). Requires the user to have connected
  their Google account via OAuth and have access to the specified property.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Google.Analytics
  alias MarketMySpec.McpServers.Validators

  schema do
    field(:display_name, :string,
      required: true,
      description: "Display name for the custom metric"
    )

    field(:parameter_name, :string,
      required: true,
      description: "Parameter name (event parameter)"
    )

    field(:measurement_unit, :string,
      required: true,
      description:
        "Measurement unit: STANDARD, CURRENCY, FEET, METERS, KILOMETERS, MILES, MILLISECONDS, SECONDS, MINUTES, HOURS. Note: CURRENCY requires restricted_metric_types"
    )

    field(:scope, :string, required: true, description: "Scope of the metric (EVENT)")
    field(:description, :string, required: false, description: "Description of the custom metric")

    field(:restricted_metric_type, :string,
      required: false,
      description:
        "Required when measurement_unit is CURRENCY, must not be set otherwise. Valid values: COST_DATA or REVENUE_DATA"
    )
  end

  @valid_scopes ["EVENT"]
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
           {:ok, validated_params} <- validate_params(params),
           {:ok, property_id} <- get_property_id(scope),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, result} <-
             Analytics.create_custom_metric(
               conn,
               "properties/#{property_id}",
               validated_params
             ) do
        format_response(result)
      else
        {:error, :missing_property_id} ->
          error_response(
            "Google Analytics Property ID is not set for this account. Set google_analytics_property_id on the active account."
          )

        {:error, :invalid_scope, scope} ->
          error_response(
            "Invalid scope '#{scope}'. Must be one of: #{Enum.join(@valid_scopes, ", ")}"
          )

        {:error, :invalid_measurement_unit, unit} ->
          error_response(
            "Invalid measurement unit '#{unit}'. Must be one of: #{Enum.join(@valid_measurement_units, ", ")}"
          )

        {:error, :restricted_metric_type_requires_currency} ->
          error_response("restricted_metric_type can only be set for CURRENCY measurement unit.")

        {:error, :currency_requires_restricted_metric_type} ->
          error_response(
            "CURRENCY measurement unit requires restricted_metric_type parameter. Valid values: COST_DATA or REVENUE_DATA"
          )

        {:error, :invalid_restricted_metric_type, type} ->
          error_response(
            "Invalid restricted_metric_type '#{type}'. Valid values: COST_DATA or REVENUE_DATA"
          )

        {:error, reason} ->
          error_response("Failed to create custom metric: #{inspect(reason)}")
      end

    {:reply, response, frame}
  end

  defp validate_params(params) do
    scope = Map.get(params, :scope)
    measurement_unit = Map.get(params, :measurement_unit)
    restricted_type = params[:restricted_metric_type]

    with :ok <- check_scope(scope),
         :ok <- check_measurement_unit(measurement_unit),
         :ok <- check_restricted_type_pairing(restricted_type, measurement_unit) do
      {:ok, build_custom_metric(params, scope, measurement_unit, restricted_type)}
    end
  end

  defp check_scope(scope) when scope in @valid_scopes, do: :ok
  defp check_scope(scope), do: {:error, :invalid_scope, scope}

  defp check_measurement_unit(unit) when unit in @valid_measurement_units, do: :ok
  defp check_measurement_unit(unit), do: {:error, :invalid_measurement_unit, unit}

  defp check_restricted_type_pairing(restricted_type, "CURRENCY") do
    check_currency_restricted_type(restricted_type)
  end

  defp check_restricted_type_pairing(nil, _measurement_unit), do: :ok

  defp check_restricted_type_pairing(_restricted_type, _measurement_unit),
    do: {:error, :restricted_metric_type_requires_currency}

  defp check_currency_restricted_type(nil), do: {:error, :currency_requires_restricted_metric_type}

  defp check_currency_restricted_type(restricted_type)
       when restricted_type in ["COST_DATA", "REVENUE_DATA"],
       do: :ok

  defp check_currency_restricted_type(restricted_type),
    do: {:error, :invalid_restricted_metric_type, restricted_type}

  defp build_custom_metric(params, scope, measurement_unit, restricted_type) do
    %{
      displayName: params.display_name,
      parameterName: params.parameter_name,
      measurementUnit: measurement_unit,
      scope: scope
    }
    |> maybe_put(:description, params[:description])
    |> maybe_put_restricted_type(restricted_type, measurement_unit)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_restricted_type(map, restricted_type, "CURRENCY") when not is_nil(restricted_type),
    do: Map.put(map, :restrictedMetricType, [restricted_type])

  defp maybe_put_restricted_type(map, _restricted_type, _unit), do: map

  defp get_property_id(scope) do
    case scope.active_account.google_analytics_property_id do
      nil -> {:error, :missing_property_id}
      "" -> {:error, :missing_property_id}
      property_id -> {:ok, property_id}
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
    Successfully created custom metric:

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
