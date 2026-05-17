defmodule MarketMySpec.McpServers.Engagements.Tools.StageResponse do
  @moduledoc """
  MCP tool: stage a polished comment draft as a Touchpoint.

  Looks up the Thread by UUID within the caller's account scope, builds
  a UTM-tracked version of `link_target` using the Thread's source scheme,
  replaces the bare URL in `polished_body` with the UTM URL, creates a
  staged Touchpoint, and returns the Touchpoint id.

  On cross-account access returns an error without creating any row.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.Posting
  alias MarketMySpec.Engagements.ThreadsRepository
  alias MarketMySpec.Engagements.TouchpointsRepository

  schema do
    field :thread_id, :string, required: true, doc: "UUID of the persisted Thread record"
    field :polished_body, :string, required: true, doc: "Polished comment body text"
    field :link_target, :string, required: false, doc: "URL to embed as a UTM-tracked link in the body"
    field :angle, :string, required: false, doc: "Agent's reasoning angle for this specific reply"
    field :campaign, :string, required: false,
      doc: "Optional utm_campaign override. Defaults to subreddit / category slug; pass a thread-specific slug here when you want GA4 to separate touchpoints within the same venue (e.g. 'claudeai-stress-testing-harness')."
  end

  @impl true
  def execute(%{thread_id: thread_id, polished_body: polished_body} = params, frame) do
    scope = frame.assigns.current_scope
    link_target = Map.get(params, :link_target)
    angle = Map.get(params, :angle)
    campaign = Map.get(params, :campaign)

    case ThreadsRepository.get_thread_by_id(scope, thread_id) do
      {:error, :not_found} ->
        err = Jason.encode!(%{"error" => "not_found", "message" => "Thread not found. Run search_engagements first."})
        {:reply,
         Response.tool()
         |> Response.text(err)
         |> Map.put(:isError, true),
         frame}

      {:ok, thread} ->
        {embedded_body, utm_link} = embed_utm(thread, polished_body, link_target, campaign)

        attrs = %{
          thread_id: thread.id,
          polished_body: embedded_body,
          link_target: link_target,
          state: :staged,
          angle: angle
        }

        case TouchpointsRepository.create_staged_touchpoint(scope, attrs) do
          {:ok, touchpoint} ->
            payload =
              %{"touchpoint_id" => touchpoint.id, "staged" => true}
              |> maybe_put("utm_link", utm_link)

            {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

          {:error, changeset} ->
            err = Jason.encode!(%{"error" => "validation_failed", "details" => format_errors(changeset)})
            {:reply,
             Response.tool()
             |> Response.text(err)
             |> Map.put(:isError, true),
             frame}
        end
    end
  end

  defp embed_utm(_thread, body, nil, _campaign), do: {body, nil}

  defp embed_utm(thread, body, link_target, campaign) do
    utm_url = Posting.build_utm_url(thread, link_target, campaign)
    embedded = String.replace(body, link_target, utm_url)
    {embedded, utm_url}
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
