defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.UpdateCustomDimension do
  @moduledoc """
  Updates a custom dimension for a Google Analytics 4 property.

  Updates specific fields of a custom dimension. The update_mask parameter specifies
  which fields should be updated. Use "*" to update all fields. Note that parameter_name
  and scope cannot be updated after creation. Requires the user to have connected their
  Google account via OAuth and have access to the specified property.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Google.Analytics
  alias MarketMySpec.McpServers.Validators

  schema do
    field(:name, :string,
      required: true,
      description:
        "The resource name of the custom dimension (e.g., properties/1234/customDimensions/5678)"
    )

    field(:display_name, :string,
      required: false,
      description: "Display name for the custom dimension"
    )

    field(:description, :string,
      required: false,
      description: "Description of the custom dimension"
    )

    field(:disallow_ads_personalization, :boolean,
      required: false,
      description: "Whether to disallow ads personalization for this dimension"
    )

    field(:update_mask, :string,
      required: true,
      description:
        "Comma-separated list of fields to update (e.g., 'displayName,description') or '*' for all fields"
    )
  end

  @impl true
  def execute(params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, dimension_name} <- validate_dimension_name(params.name),
           {:ok, validated_params} <- validate_params(params),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, result} <-
             Analytics.update_custom_dimension(
               conn,
               dimension_name,
               validated_params,
               params.update_mask
             ) do
        format_response(result)
      else
        {:error, :invalid_dimension_name} ->
          error_response(
            "Invalid custom dimension name. Expected format: properties/1234/customDimensions/5678"
          )

        {:error, :no_fields_to_update} ->
          error_response(
            "No fields specified for update. Please provide at least one field to update."
          )

        {:error, reason} ->
          error_response("Failed to update custom dimension: #{inspect(reason)}")
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

  defp validate_params(params) do
    # Build the custom dimension map with only the fields that are being updated
    custom_dimension = %{}

    custom_dimension =
      if params[:display_name] do
        Map.put(custom_dimension, :displayName, params.display_name)
      else
        custom_dimension
      end

    custom_dimension =
      if params[:description] do
        Map.put(custom_dimension, :description, params.description)
      else
        custom_dimension
      end

    custom_dimension =
      if Map.has_key?(params, :disallow_ads_personalization) do
        Map.put(
          custom_dimension,
          :disallowAdsPersonalization,
          params.disallow_ads_personalization
        )
      else
        custom_dimension
      end

    if map_size(custom_dimension) == 0 and params.update_mask != "*" do
      {:error, :no_fields_to_update}
    else
      {:ok, custom_dimension}
    end
  end

  defp format_response(dimension) do
    Response.tool()
    |> Response.text("""
    Successfully updated custom dimension:

    Custom Dimension: #{dimension.displayName || "Unnamed"}
    - Name: #{dimension.name}
    - Parameter Name: #{dimension.parameterName}
    - Scope: #{dimension.scope || "N/A"}
    - Description: #{dimension.description || "No description"}
    - Disallow Ads Personalization: #{dimension.disallowAdsPersonalization || false}
    """)
  end

  defp error_response(message) when is_binary(message) do
    Response.tool()
    |> Response.error(message)
  end
end
