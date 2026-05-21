defmodule MarketMySpec.McpServers.Engagements.Tools.PolishTouchpoint do
  @moduledoc """
  MCP tool: write the polished prose body onto a staged Touchpoint, gated
  by Vale lint feedback against the account's saved style guide.

  This is the only MCP tool that writes a Touchpoint's `polished_body`.
  The agent is expected to dictate a draft with the founder, polish it
  together, then call this tool with the agreed text.

  ## Loop semantics

  The Linter (`MarketMySpec.Linter`) runs against `polished_body` using
  the account's saved Vale configuration. The response always includes
  the alerts produced — even when empty.

  - **No alerts** (clean prose or no saved configuration) — `polished_body`
    is persisted on the Touchpoint. The response carries the updated
    Touchpoint and an empty alerts list.

  - **One or more alerts** — `polished_body` is NOT persisted. The
    Touchpoint's body stays at whatever it was before. The response
    carries the (unchanged) Touchpoint and the alerts list so the agent
    can revise the prose with the founder and retry.

  Cross-account access (a touchpoint owned by a different account)
  returns `:not_found` and modifies nothing.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements
  alias MarketMySpec.Linter

  schema do
    field :touchpoint_id, :string,
      required: true,
      doc: "UUID of the staged Touchpoint to polish."

    field :polished_body, :string,
      required: true,
      doc:
        "The polished prose body the agent and founder have agreed on. If Vale alerts come back non-empty, this body is NOT persisted — revise with the founder and re-call."
  end

  @impl true
  def execute(%{touchpoint_id: touchpoint_id, polished_body: polished_body}, frame) do
    scope = frame.assigns.current_scope

    case Engagements.get_touchpoint_by_id(scope, touchpoint_id) do
      {:error, :not_found} ->
        respond_not_found(frame, touchpoint_id)

      {:ok, touchpoint} ->
        case Linter.lint(scope, polished_body) do
          {:ok, []} ->
            write_and_respond(scope, touchpoint, polished_body, frame)

          {:ok, alerts} ->
            respond_blocked(frame, touchpoint, alerts)

          {:error, reason} ->
            respond_lint_error(frame, reason)
        end
    end
  end

  defp write_and_respond(scope, touchpoint, polished_body, frame) do
    case Engagements.update_touchpoint(scope, touchpoint.id, %{polished_body: polished_body}) do
      {:ok, updated} -> respond_ok(frame, updated, [])
      {:error, changeset} -> respond_validation_error(frame, changeset)
    end
  end

  defp respond_ok(frame, touchpoint, alerts) do
    payload = %{
      "touchpoint" => encode_touchpoint(touchpoint),
      "alerts" => alerts
    }

    {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}
  end

  defp respond_blocked(frame, touchpoint, alerts) do
    payload = %{
      "touchpoint" => encode_touchpoint(touchpoint),
      "alerts" => alerts
    }

    {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}
  end

  defp respond_not_found(frame, touchpoint_id) do
    body =
      Jason.encode!(%{
        "error" => "not_found",
        "message" => "Touchpoint not found: #{touchpoint_id}"
      })

    {:reply,
     Response.tool()
     |> Response.text(body)
     |> Map.put(:isError, true), frame}
  end

  defp respond_lint_error(frame, reason) do
    body =
      Jason.encode!(%{
        "error" => "lint_failed",
        "message" => to_string(reason)
      })

    {:reply,
     Response.tool()
     |> Response.text(body)
     |> Map.put(:isError, true), frame}
  end

  defp respond_validation_error(frame, changeset) do
    body =
      Jason.encode!(%{
        "error" => "validation_failed",
        "details" => inspect(changeset.errors)
      })

    {:reply,
     Response.tool()
     |> Response.text(body)
     |> Map.put(:isError, true), frame}
  end

  defp encode_touchpoint(tp) do
    %{
      "id" => tp.id,
      "state" => tp.state && to_string(tp.state),
      "angle" => tp.angle,
      "polished_body" => tp.polished_body,
      "utm_source" => tp.utm_source,
      "utm_medium" => tp.utm_medium,
      "utm_campaign" => tp.utm_campaign,
      "comment_url" => tp.comment_url,
      "posted_at" => tp.posted_at && DateTime.to_iso8601(tp.posted_at)
    }
  end
end
