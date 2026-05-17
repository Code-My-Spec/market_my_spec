defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.CreateKeyEvent do
  @moduledoc """
  Creates a key event for a Google Analytics 4 property.

  Marks an existing event as a key event (formerly known as a conversion).
  Key events are important user interactions that you want to track. If you
  want to assign a default monetary value, you must provide both default_value
  and currency_code. Requires the user to have connected their Google account
  via OAuth and have access to the specified property.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Google.Analytics
  alias MarketMySpec.McpServers.Validators

  schema do
    field(:event_name, :string,
      required: true,
      description: "Name of the event to mark as a key event"
    )

    field(:counting_method, :string,
      required: false,
      description:
        "How to count the event: ONCE_PER_EVENT or ONCE_PER_SESSION (default: ONCE_PER_EVENT)"
    )

    field(:default_value, :float,
      required: false,
      description: "Default numeric value for the conversion (requires currency_code if provided)"
    )

    field(:currency_code, :string,
      required: false,
      description:
        "Currency code for the default value (e.g., USD, EUR, GBP). Required when default_value is provided"
    )
  end

  @valid_counting_methods ["ONCE_PER_EVENT", "ONCE_PER_SESSION"]

  @impl true
  def execute(params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, validated_params} <- validate_params(params),
           {:ok, property_id} <- get_property_id(scope),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, result} <-
             Analytics.create_key_event(
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

        {:error, :invalid_counting_method, method} ->
          error_response(
            "Invalid counting method '#{method}'. Must be one of: #{Enum.join(@valid_counting_methods, ", ")}"
          )

        {:error, :default_value_requires_currency_code} ->
          error_response(
            "When providing a default_value, you must also provide a currency_code (e.g., USD, EUR, GBP)"
          )

        {:error, :currency_code_requires_default_value} ->
          error_response("currency_code can only be set when default_value is provided")

        {:error, reason} ->
          error_response("Failed to create key event: #{inspect(reason)}")
      end

    {:reply, response, frame}
  end

  defp validate_params(params) do
    counting_method = Map.get(params, :counting_method, "ONCE_PER_EVENT")

    cond do
      counting_method && counting_method not in @valid_counting_methods ->
        {:error, :invalid_counting_method, counting_method}

      # Validate that default_value requires currency_code
      params[:default_value] && !params[:currency_code] ->
        {:error, :default_value_requires_currency_code}

      # Validate that currency_code requires default_value
      params[:currency_code] && !params[:default_value] ->
        {:error, :currency_code_requires_default_value}

      true ->
        key_event = %{
          eventName: params.event_name
        }

        key_event =
          if counting_method do
            Map.put(key_event, :countingMethod, counting_method)
          else
            key_event
          end

        key_event =
          if params[:default_value] do
            default_value = %{numericValue: params.default_value}

            default_value =
              if params[:currency_code] do
                Map.put(default_value, :currencyCode, params.currency_code)
              else
                default_value
              end

            Map.put(key_event, :defaultValue, default_value)
          else
            key_event
          end

        {:ok, key_event}
    end
  end

  defp get_property_id(scope) do
    case scope.active_account.google_analytics_property_id do
      nil -> {:error, :missing_property_id}
      "" -> {:error, :missing_property_id}
      property_id -> {:ok, property_id}
    end
  end

  defp format_response(key_event) do
    default_value =
      if key_event.defaultValue do
        value = key_event.defaultValue.numericValue || "N/A"

        currency =
          if key_event.defaultValue.currencyCode do
            " #{key_event.defaultValue.currencyCode}"
          else
            ""
          end

        "#{value}#{currency}"
      else
        "N/A"
      end

    Response.tool()
    |> Response.text("""
    Successfully created key event:

    Key Event: #{key_event.eventName || "Unnamed"}
    - Name: #{key_event.name}
    - Counting Method: #{key_event.countingMethod || "N/A"}
    - Default Value: #{default_value}
    - Custom: #{key_event.custom || false}
    """)
  end

  defp error_response(message) when is_binary(message) do
    Response.tool()
    |> Response.error(message)
  end
end
