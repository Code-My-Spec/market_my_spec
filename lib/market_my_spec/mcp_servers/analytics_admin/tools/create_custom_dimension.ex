defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.CreateCustomDimension do
  @moduledoc """
  Creates a custom dimension for a Google Analytics 4 property.

  Allows creating new custom dimensions with a display name, parameter name,
  scope (EVENT, USER, or ITEM), and optional description. Requires the user
  to have connected their Google account via OAuth and have access to the
  specified property.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Google.Analytics
  alias MarketMySpec.McpServers.Validators

  schema do
    field(:display_name, :string,
      required: true,
      description: "Display name for the custom dimension"
    )

    field(:parameter_name, :string,
      required: true,
      description: "Parameter name (event parameter, user property, or item parameter)"
    )

    field(:scope, :string,
      required: true,
      description: "Scope of the dimension: EVENT, USER, or ITEM"
    )

    field(:description, :string,
      required: false,
      description: "Description of the custom dimension"
    )
  end

  @valid_scopes ["EVENT", "USER", "ITEM"]

  @impl true
  def execute(params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, validated_params} <- validate_params(params),
           {:ok, property_id} <- get_property_id(scope),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, result} <-
             Analytics.create_custom_dimension(
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

        {:error, reason} ->
          error_response("Failed to create custom dimension: #{inspect(reason)}")
      end

    {:reply, response, frame}
  end

  defp validate_params(params) do
    scope = Map.get(params, :scope)

    if scope in @valid_scopes do
      custom_dimension = %{
        displayName: params.display_name,
        parameterName: params.parameter_name,
        scope: scope
      }

      custom_dimension =
        if params[:description] do
          Map.put(custom_dimension, :description, params.description)
        else
          custom_dimension
        end

      {:ok, custom_dimension}
    else
      {:error, :invalid_scope, scope}
    end
  end

  defp get_property_id(scope) do
    case scope.active_account.google_analytics_property_id do
      nil -> {:error, :missing_property_id}
      "" -> {:error, :missing_property_id}
      property_id -> {:ok, property_id}
    end
  end

  defp format_response(dimension) do
    Response.tool()
    |> Response.text("""
    Successfully created custom dimension:

    Custom Dimension: #{dimension.displayName || "Unnamed"}
    - Name: #{dimension.name}
    - Parameter Name: #{dimension.parameterName}
    - Scope: #{dimension.scope || "N/A"}
    - Description: #{dimension.description || "No description"}
    """)
  end

  defp error_response(message) when is_binary(message) do
    Response.tool()
    |> Response.error(message)
  end
end
