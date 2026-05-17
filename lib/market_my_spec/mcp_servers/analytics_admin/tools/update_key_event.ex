defmodule MarketMySpec.McpServers.AnalyticsAdmin.Tools.UpdateKeyEvent do
  @moduledoc """
  Updates a key event for a Google Analytics 4 property.

  Updates specific fields of a key event. The update_mask parameter specifies
  which fields should be updated (in snake_case). Use "*" to update all fields.
  If you want to update the default monetary value, you must provide both
  default_value and currency_code. Requires the user to have connected their
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
        "The resource name of the key event (e.g., properties/1234/keyEvents/event_name)"
    )

    field(:counting_method, :string,
      required: false,
      description: "How to count the event: ONCE_PER_EVENT or ONCE_PER_SESSION"
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

    field(:update_mask, :string,
      required: true,
      description:
        "Comma-separated list of fields to update in snake_case (e.g., 'counting_method,default_value') or '*' for all fields"
    )
  end

  @valid_counting_methods ["ONCE_PER_EVENT", "ONCE_PER_SESSION"]

  @impl true
  def execute(params, frame) do
    response =
      with {:ok, scope} <- Validators.validate_scope(frame),
           {:ok, key_event_name} <- validate_key_event_name(params.name),
           {:ok, validated_params} <- validate_params(params),
           {:ok, conn} <- Analytics.get_connection(scope),
           {:ok, result} <-
             Analytics.update_key_event(
               conn,
               key_event_name,
               validated_params,
               params.update_mask
             ) do
        format_response(result)
      else
        {:error, :invalid_key_event_name} ->
          error_response(
            "Invalid key event name. Expected format: properties/1234/keyEvents/event_name"
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

        {:error, :no_fields_to_update} ->
          error_response(
            "No fields specified for update. Please provide at least one field to update."
          )

        {:error, reason} ->
          error_response("Failed to update key event: #{inspect(reason)}")
      end

    {:reply, response, frame}
  end

  defp validate_key_event_name(name) when is_binary(name) do
    # Validate the format: properties/{property_id}/keyEvents/{event_name}
    case Regex.match?(~r/^properties\/\d+\/keyEvents\//, name) do
      true -> {:ok, name}
      false -> {:error, :invalid_key_event_name}
    end
  end

  defp validate_key_event_name(_), do: {:error, :invalid_key_event_name}

  defp validate_params(params) do
    counting_method = params[:counting_method]

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
        # Build the key event map with only the fields that are being updated
        key_event = %{name: params.name}

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

        # Check if any fields besides name were added
        if map_size(key_event) == 1 and params.update_mask != "*" do
          {:error, :no_fields_to_update}
        else
          {:ok, key_event}
        end
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
    Successfully updated key event:

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
