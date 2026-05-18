defmodule MarketMySpec.McpServers.Engagements.Tools.UpdateTouchpoint do
  @moduledoc """
  MCP tool: edit a Touchpoint — transition state and/or revise the
  polished_body / angle.

  All fields except `touchpoint_id` are optional. The tool changes only the
  fields the caller supplies; omitted fields are preserved. Transitioning
  to `:posted` requires `comment_url` and `posted_at`. An empty
  `polished_body` is rejected with a validation error and the existing
  value stays untouched.

  Cross-account access returns an error.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.TouchpointsRepository

  schema do
    field :touchpoint_id, :string, required: true, doc: "Touchpoint UUID"
    field :state, :string, required: false, doc: "Target state: staged | posted | abandoned. Omit to leave state unchanged."
    field :comment_url, :string, required: false, doc: "Live comment URL (required for :posted)"
    field :posted_at, :string, required: false, doc: "ISO8601 timestamp (required for :posted)"
    field :polished_body, :string, required: false, doc: "Revised polished body. Must be non-empty when provided."
    field :angle, :string, required: false, doc: "Revised reasoning angle for this touchpoint."
  end

  @impl true
  def execute(%{touchpoint_id: touchpoint_id} = params, frame) do
    scope = frame.assigns.current_scope
    state = Map.get(params, :state)
    comment_url = Map.get(params, :comment_url)
    posted_at_str = Map.get(params, :posted_at)
    polished_body = Map.get(params, :polished_body)
    angle = Map.get(params, :angle)

    posted_at =
      if posted_at_str do
        case DateTime.from_iso8601(posted_at_str) do
          {:ok, dt, _} -> DateTime.truncate(dt, :second)
          _ -> nil
        end
      end

    attrs =
      %{}
      |> maybe_put_state(state)
      |> maybe_put(:comment_url, comment_url)
      |> maybe_put(:posted_at, posted_at)
      |> maybe_put(:polished_body, polished_body)
      |> maybe_put(:angle, angle)

    case TouchpointsRepository.update_touchpoint(scope, touchpoint_id, attrs) do
      {:ok, touchpoint} ->
        payload = %{
          "touchpoint_id" => touchpoint.id,
          "state" => to_string(touchpoint.state)
        }

        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, :not_found} ->
        err = Jason.encode!(%{"error" => "not_found", "message" => "Touchpoint not found: #{touchpoint_id}"})
        {:reply, Response.tool() |> Response.text(err) |> Map.put(:isError, true), frame}

      {:error, changeset} ->
        err = Jason.encode!(%{"error" => "validation_failed", "details" => format_errors(changeset)})
        {:reply, Response.tool() |> Response.text(err) |> Map.put(:isError, true), frame}
    end
  rescue
    ArgumentError ->
      err = Jason.encode!(%{"error" => "invalid_state", "message" => "State must be: staged, posted, or abandoned"})
      {:reply, Response.tool() |> Response.text(err) |> Map.put(:isError, true), frame}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_state(map, nil), do: map
  defp maybe_put_state(map, state) when is_binary(state),
    do: Map.put(map, :state, String.to_existing_atom(state))

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> inspect()
  end
end
