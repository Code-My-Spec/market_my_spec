defmodule MarketMySpec.Google.Analytics do
  @moduledoc """
  Context module for interacting with the Google Analytics Admin API.

  Handles connection building, token management, and provides wrapper functions
  for common Analytics Admin API operations. All operations are scoped to the
  authenticated user and use their OAuth tokens from the integrations table.

  ## Authentication Flow

  1. User connects Google account via OAuth (stored in integrations table)
  2. MCP tools fetch integration for current user scope
  3. Connection is built with user's access token
  4. API calls are made on behalf of the user
  5. Token refresh happens automatically when expired

  ## Usage

      iex> {:ok, conn} = Google.Analytics.get_connection(scope)
      iex> Google.Analytics.list_accounts(conn)
      {:ok, %GoogleApi.AnalyticsAdmin.V1beta.Model.GoogleAnalyticsAdminV1betaListAccountsResponse{}}
  """

  alias MarketMySpec.Integrations
  alias MarketMySpec.Users.Scope
  alias GoogleApi.AnalyticsAdmin.V1beta.Api.{Accounts, Properties}
  alias GoogleApi.AnalyticsAdmin.V1beta.Connection

  @doc """
  Builds a Google Analytics Admin API connection for the scoped user.

  Fetches the user's Google OAuth integration and creates a connection
  using their access token. Returns an error if the user hasn't connected
  their Google account or if the integration is invalid.

  ## Examples

      iex> get_connection(scope)
      {:ok, %Connection{}}

      iex> get_connection(scope_without_google)
      {:error, :not_found}
  """
  @spec get_connection(Scope.t()) ::
          {:ok, Tesla.Client.t()} | {:error, :not_found | :token_expired}
  def get_connection(%Scope{} = scope) do
    with {:ok, integration} <- Integrations.get_integration(scope, :google),
         {:ok, token} <- get_valid_token(scope, integration) do
      conn = Connection.new(token)
      {:ok, conn}
    end
  end

  @doc """
  Lists all Google Analytics accounts accessible by the authenticated user.

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> list_accounts(conn)
      {:ok, %GoogleAnalyticsAdminV1betaListAccountsResponse{accounts: [...]}}
  """
  @spec list_accounts(Tesla.Client.t()) :: {:ok, map()} | {:error, term()}
  def list_accounts(conn) do
    case Accounts.analyticsadmin_accounts_list(conn) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all properties for a given Google Analytics account.

  ## Parameters
  - conn: The API connection
  - account_name: The account resource name (e.g., "accounts/123456")

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> list_properties(conn, "accounts/123456")
      {:ok, %GoogleAnalyticsAdminV1betaListPropertiesResponse{properties: [...]}}
  """
  @spec list_properties(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_properties(conn, account_name) when is_binary(account_name) do
    case Properties.analyticsadmin_properties_list(
           conn,
           filter: "parent:#{account_name}"
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets details for a specific property.

  ## Parameters
  - conn: The API connection
  - property_name: The property resource name (e.g., "properties/123456")

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> get_property(conn, "properties/123456")
      {:ok, %GoogleAnalyticsAdminV1betaProperty{}}
  """
  @spec get_property(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_property(conn, property_name) when is_binary(property_name) do
    case Properties.analyticsadmin_properties_get(conn, property_name) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists custom dimensions for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - property_name: The property resource name (e.g., "properties/123456")

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> list_custom_dimensions(conn, "properties/123456")
      {:ok, %GoogleAnalyticsAdminV1betaListCustomDimensionsResponse{customDimensions: [...]}}
  """
  @spec list_custom_dimensions(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_custom_dimensions(conn, property_name) when is_binary(property_name) do
    case Properties.analyticsadmin_properties_custom_dimensions_list(conn, property_name) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets a custom dimension for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - dimension_name: The custom dimension resource name (e.g., "properties/123456/customDimensions/5678")

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> get_custom_dimension(conn, "properties/123456/customDimensions/5678")
      {:ok, %GoogleAnalyticsAdminV1betaCustomDimension{}}
  """
  @spec get_custom_dimension(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_custom_dimension(conn, dimension_name) when is_binary(dimension_name) do
    case Properties.analyticsadmin_properties_custom_dimensions_get(conn, dimension_name) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a custom dimension for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - property_name: The property resource name (e.g., "properties/123456")
  - custom_dimension: A map containing the custom dimension details:
    - displayName: Display name for the dimension
    - parameterName: Parameter name (event parameter, user property, or item parameter)
    - scope: Scope of the dimension (EVENT, USER, or ITEM)
    - description: Optional description

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> create_custom_dimension(conn, "properties/123456", %{
      ...>   displayName: "User Role",
      ...>   parameterName: "user_role",
      ...>   scope: "USER",
      ...>   description: "The role of the user"
      ...> })
      {:ok, %GoogleAnalyticsAdminV1betaCustomDimension{}}
  """
  @spec create_custom_dimension(Tesla.Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def create_custom_dimension(conn, property_name, custom_dimension)
      when is_binary(property_name) and is_map(custom_dimension) do
    case Properties.analyticsadmin_properties_custom_dimensions_create(
           conn,
           property_name,
           body: custom_dimension
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates a custom dimension for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - dimension_name: The custom dimension resource name (e.g., "properties/123456/customDimensions/5678")
  - custom_dimension: A map containing the fields to update
  - update_mask: Comma-separated list of field paths to update (e.g., "displayName,description") or "*" for all

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> update_custom_dimension(conn, "properties/123456/customDimensions/5678", %{
      ...>   displayName: "Updated User Role"
      ...> }, "displayName")
      {:ok, %GoogleAnalyticsAdminV1betaCustomDimension{}}
  """
  @spec update_custom_dimension(Tesla.Client.t(), String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def update_custom_dimension(conn, dimension_name, custom_dimension, update_mask)
      when is_binary(dimension_name) and is_map(custom_dimension) and is_binary(update_mask) do
    case Properties.analyticsadmin_properties_custom_dimensions_patch(
           conn,
           dimension_name,
           body: custom_dimension,
           updateMask: update_mask
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Archives a custom dimension for a given Google Analytics property.

  Archived dimensions are no longer available for use but their historical data is preserved.

  ## Parameters
  - conn: The API connection
  - dimension_name: The custom dimension resource name (e.g., "properties/123456/customDimensions/5678")

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> archive_custom_dimension(conn, "properties/123456/customDimensions/5678")
      {:ok, %GoogleAnalyticsAdminV1betaCustomDimension{}}
  """
  @spec archive_custom_dimension(Tesla.Client.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def archive_custom_dimension(conn, dimension_name) when is_binary(dimension_name) do
    case Properties.analyticsadmin_properties_custom_dimensions_archive(conn, dimension_name) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists custom metrics for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - property_name: The property resource name (e.g., "properties/123456")

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> list_custom_metrics(conn, "properties/123456")
      {:ok, %GoogleAnalyticsAdminV1betaListCustomMetricsResponse{customMetrics: [...]}}
  """
  @spec list_custom_metrics(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_custom_metrics(conn, property_name) when is_binary(property_name) do
    case Properties.analyticsadmin_properties_custom_metrics_list(conn, property_name) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a custom metric for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - property_name: The property resource name (e.g., "properties/123456")
  - custom_metric: A map containing the custom metric details:
    - displayName: Display name for the metric
    - parameterName: Parameter name (event parameter)
    - measurementUnit: Measurement unit (STANDARD, CURRENCY, etc.)
    - scope: Scope of the metric (EVENT)
    - description: Optional description

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> create_custom_metric(conn, "properties/123456", %{
      ...>   displayName: "Purchase Value",
      ...>   parameterName: "purchase_value",
      ...>   measurementUnit: "CURRENCY",
      ...>   scope: "EVENT",
      ...>   description: "The value of a purchase"
      ...> })
      {:ok, %GoogleAnalyticsAdminV1betaCustomMetric{}}
  """
  @spec create_custom_metric(Tesla.Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def create_custom_metric(conn, property_name, custom_metric)
      when is_binary(property_name) and is_map(custom_metric) do
    case Properties.analyticsadmin_properties_custom_metrics_create(
           conn,
           property_name,
           body: custom_metric
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets a custom metric for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - metric_name: The custom metric resource name (e.g., "properties/123456/customMetrics/5678")

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> get_custom_metric(conn, "properties/123456/customMetrics/5678")
      {:ok, %GoogleAnalyticsAdminV1betaCustomMetric{}}
  """
  @spec get_custom_metric(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_custom_metric(conn, metric_name) when is_binary(metric_name) do
    case Properties.analyticsadmin_properties_custom_metrics_get(conn, metric_name) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates a custom metric for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - metric_name: The custom metric resource name (e.g., "properties/123456/customMetrics/5678")
  - custom_metric: A map containing the fields to update
  - update_mask: Comma-separated list of field paths to update (e.g., "displayName,description") or "*" for all

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> update_custom_metric(conn, "properties/123456/customMetrics/5678", %{
      ...>   displayName: "Updated Purchase Value"
      ...> }, "displayName")
      {:ok, %GoogleAnalyticsAdminV1betaCustomMetric{}}
  """
  @spec update_custom_metric(Tesla.Client.t(), String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def update_custom_metric(conn, metric_name, custom_metric, update_mask)
      when is_binary(metric_name) and is_map(custom_metric) and is_binary(update_mask) do
    case Properties.analyticsadmin_properties_custom_metrics_patch(
           conn,
           metric_name,
           body: custom_metric,
           updateMask: update_mask
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Archives a custom metric for a given Google Analytics property.

  Archived metrics are no longer available for use but their historical data is preserved.

  ## Parameters
  - conn: The API connection
  - metric_name: The custom metric resource name (e.g., "properties/123456/customMetrics/5678")

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> archive_custom_metric(conn, "properties/123456/customMetrics/5678")
      {:ok, %GoogleAnalyticsAdminV1betaCustomMetric{}}
  """
  @spec archive_custom_metric(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def archive_custom_metric(conn, metric_name) when is_binary(metric_name) do
    case Properties.analyticsadmin_properties_custom_metrics_archive(conn, metric_name) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists key events for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - property_name: The property resource name (e.g., "properties/123456")
  - page_size: Optional maximum number of resources to return (max 200)
  - page_token: Optional page token for pagination

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> list_key_events(conn, "properties/123456")
      {:ok, %GoogleAnalyticsAdminV1betaListKeyEventsResponse{keyEvents: [...]}}
  """
  @spec list_key_events(Tesla.Client.t(), String.t(), integer() | nil, String.t() | nil) ::
          {:ok, map()} | {:error, term()}
  def list_key_events(conn, property_name, page_size \\ nil, page_token \\ nil)
      when is_binary(property_name) do
    opts = []
    opts = if page_size, do: [{:pageSize, page_size} | opts], else: opts
    opts = if page_token, do: [{:pageToken, page_token} | opts], else: opts

    case Properties.analyticsadmin_properties_key_events_list(conn, property_name, opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a key event for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - property_name: The property resource name (e.g., "properties/123456")
  - key_event: A map containing the key event details:
    - eventName: Name of the event to mark as a key event
    - countingMethod: Optional counting method (ONCE_PER_EVENT or ONCE_PER_SESSION)
    - defaultValue: Optional map with numericValue

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> create_key_event(conn, "properties/123456", %{
      ...>   eventName: "purchase",
      ...>   countingMethod: "ONCE_PER_EVENT",
      ...>   defaultValue: %{numericValue: 10.0}
      ...> })
      {:ok, %GoogleAnalyticsAdminV1betaKeyEvent{}}
  """
  @spec create_key_event(Tesla.Client.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def create_key_event(conn, property_name, key_event)
      when is_binary(property_name) and is_map(key_event) do
    case Properties.analyticsadmin_properties_key_events_create(
           conn,
           property_name,
           body: key_event
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates a key event for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - key_event_name: The key event resource name (e.g., "properties/123456/keyEvents/event_name")
  - key_event: A map containing the fields to update (must include name field)
  - update_mask: Comma-separated list of field paths to update in snake_case (e.g., "counting_method") or "*" for all

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> update_key_event(conn, "properties/123456/keyEvents/purchase", %{
      ...>   name: "properties/123456/keyEvents/purchase",
      ...>   countingMethod: "ONCE_PER_SESSION"
      ...> }, "counting_method")
      {:ok, %GoogleAnalyticsAdminV1betaKeyEvent{}}
  """
  @spec update_key_event(Tesla.Client.t(), String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def update_key_event(conn, key_event_name, key_event, update_mask)
      when is_binary(key_event_name) and is_map(key_event) and is_binary(update_mask) do
    case Properties.analyticsadmin_properties_key_events_patch(
           conn,
           key_event_name,
           body: key_event,
           updateMask: update_mask
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a key event for a given Google Analytics property.

  ## Parameters
  - conn: The API connection
  - key_event_name: The key event resource name (e.g., "properties/123456/keyEvents/event_name")

  ## Examples

      iex> {:ok, conn} = get_connection(scope)
      iex> delete_key_event(conn, "properties/123456/keyEvents/purchase")
      {:ok, %{}}
  """
  @spec delete_key_event(Tesla.Client.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def delete_key_event(conn, key_event_name) when is_binary(key_event_name) do
    case Properties.analyticsadmin_properties_key_events_delete(conn, key_event_name) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private Functions

  defp get_valid_token(scope, integration) do
    if integration_expired?(integration) do
      case Integrations.refresh_token(scope, :google) do
        {:ok, refreshed} -> {:ok, refreshed.access_token}
        {:error, _} = error -> error
      end
    else
      {:ok, integration.access_token}
    end
  end

  defp integration_expired?(integration) do
    DateTime.compare(DateTime.utc_now(), integration.expires_at) == :gt
  end
end
