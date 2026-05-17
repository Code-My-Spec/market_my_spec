defmodule MarketMySpec.McpServers.Engagements.Tools.UpdateTouchpoint do
  @moduledoc """
  MCP tool: transition a Touchpoint between states.

  Allowed states: staged, posted, abandoned.
  Transitioning to :posted requires comment_url and posted_at.
  Cross-account access returns an error.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.TouchpointsRepository

  schema do
    field :touchpoint_id, :string, required: true, doc: "Touchpoint UUID"
    field :state, :string, required: true, doc: "Target state: staged | posted | abandoned"
    field :comment_url, :string, required: false, doc: "Live comment URL (required for :posted)"
    field :posted_at, :string, required: false, doc: "ISO8601 timestamp (required for :posted)"
  end

  @impl true
  def execute(%{touchpoint_id: touchpoint_id, state: state} = params, frame) do
    scope = frame.assigns.current_scope
    comment_url = Map.get(params, :comment_url)
    posted_at_str = Map.get(params, :posted_at)

    posted_at =
      if posted_at_str do
        case DateTime.from_iso8601(posted_at_str) do
          {:ok, dt, _} -> DateTime.truncate(dt, :second)
          _ -> nil
        end
      end

    attrs =
      %{state: String.to_existing_atom(state)}
      |> maybe_put(:comment_url, comment_url)
      |> maybe_put(:posted_at, posted_at)

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

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> inspect()
  end
end
