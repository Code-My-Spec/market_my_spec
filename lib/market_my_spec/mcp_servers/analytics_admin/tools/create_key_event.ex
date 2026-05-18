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

    with :ok <- check_counting_method(counting_method),
         :ok <- check_value_currency_pairing(params) do
      {:ok, build_key_event(params, counting_method)}
    end
  end

  defp check_counting_method(method) do
    cond do
      is_nil(method) -> :ok
      method in @valid_counting_methods -> :ok
      true -> {:error, :invalid_counting_method, method}
    end
  end

  defp check_value_currency_pairing(params) do
    has_value? = !is_nil(params[:default_value])
    has_currency? = !is_nil(params[:currency_code])
    do_check_value_currency_pairing(has_value?, has_currency?)
  end

  defp do_check_value_currency_pairing(true, false), do: {:error, :default_value_requires_currency_code}
  defp do_check_value_currency_pairing(false, true), do: {:error, :currency_code_requires_default_value}
  defp do_check_value_currency_pairing(_, _), do: :ok

  defp build_key_event(params, counting_method) do
    %{eventName: params.event_name}
    |> maybe_put(:countingMethod, counting_method)
    |> maybe_put_default_value(params)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_default_value(map, %{default_value: value} = params) when not is_nil(value) do
    default_value =
      %{numericValue: value}
      |> maybe_put(:currencyCode, params[:currency_code])

    Map.put(map, :defaultValue, default_value)
  end

  defp maybe_put_default_value(map, _params), do: map

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
