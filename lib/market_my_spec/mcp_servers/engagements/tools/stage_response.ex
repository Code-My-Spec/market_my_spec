defmodule MarketMySpec.McpServers.Engagements.Tools.StageResponse do
  @moduledoc """
  MCP tool: stage a placeholder Touchpoint on a Thread.

  The agent stages a Touchpoint after reading a Thread and forming a
  synopsis + angle. This tool persists the synopsis on the parent Thread
  (write-once), creates a `:staged` Touchpoint carrying the angle and the
  per-source UTM parameters, and returns the new Touchpoint id.

  The polished prose body is NOT settable here — story 738's
  `polish_touchpoint` tool owns the prose write path so the lint loop is
  the only way prose lands on a Touchpoint.

  ## UTM scheme

  `utm_source` and `utm_medium` are derived from the parent Thread's
  source — Reddit produces `reddit/comment`, ElixirForum produces
  `elixirforum/reply`. `utm_campaign` defaults to `<subreddit>:<thread-name>`
  for Reddit and `<category-slug>:<thread-name>` for ElixirForum; the
  agent may override it via the `utm_campaign` parameter.

  ## Synopsis behavior

  Each call writes its `synopsis` onto the parent Thread, overwriting any
  prior value. This lets the agent iterate (correct typos, refine the
  synthesis on a subsequent stage) without leaving placeholder/test
  values stuck permanently. The Thread.synopsis column is `:text`
  (no length cap at the DB layer); the Peri schema below enforces a
  generous upper bound so an oversized synopsis returns a clear
  validation error instead of an opaque crash.

  Cross-account access returns an error without creating any row.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.Posting
  alias MarketMySpec.Engagements.ThreadsRepository
  alias MarketMySpec.Engagements.TouchpointsRepository

  schema do
    field :thread_id, :string,
      required: true,
      doc: "UUID of the persisted Thread record (from a prior search_engagements call)"

    field :synopsis, {:string, {:max, 4000}},
      required: true,
      doc:
        "One-paragraph synthesis of the thread (what the discussion is about). Up to 4000 chars. Written to the parent Thread on every stage — overwrites any prior value, so placeholder/test synopses do NOT stick. Shared across all Touchpoints on the thread."

    field :angle, {:string, {:max, 4000}},
      required: true,
      doc:
        "Agent's reasoning angle for this specific reply (per-Touchpoint, not per-Thread — the same thread may be replied to multiple times with different angles). Up to 4000 chars."

    field :utm_campaign, :string,
      required: false,
      doc:
        "Optional utm_campaign override. Defaults to `<subreddit>:<thread-name>` for Reddit threads and `<category-slug>:<thread-name>` for ElixirForum threads. Pass a custom value when you want GA4 to separate touchpoints within the same venue."
  end

  @impl true
  def execute(%{thread_id: thread_id, synopsis: synopsis, angle: angle} = params, frame) do
    scope = frame.assigns.current_scope
    utm_campaign_override = Map.get(params, :utm_campaign)

    case ThreadsRepository.get_thread_by_id(scope, thread_id) do
      {:error, :not_found} ->
        respond_error(frame, "not_found", "Thread not found. Run search_engagements first.")

      {:ok, thread} ->
        utm = Posting.build_utm_params(thread, utm_campaign_override)

        attrs =
          %{
            thread_id: thread.id,
            state: :staged,
            angle: angle
          }
          |> Map.merge(utm)

        case TouchpointsRepository.create_staged_touchpoint(scope, attrs) do
          {:ok, touchpoint} ->
            _ = ThreadsRepository.set_synopsis(scope, thread.id, synopsis)

            payload = %{
              "touchpoint_id" => touchpoint.id,
              "staged" => true,
              "utm_source" => touchpoint.utm_source,
              "utm_medium" => touchpoint.utm_medium,
              "utm_campaign" => touchpoint.utm_campaign
            }

            {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

          {:error, changeset} ->
            respond_error(frame, "validation_failed", format_errors(changeset))
        end
    end
  end

  defp respond_error(frame, error, message) do
    body = Jason.encode!(%{"error" => error, "message" => message})

    {:reply,
     Response.tool()
     |> Response.text(body)
     |> Map.put(:isError, true), frame}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> inspect()
  end
end
