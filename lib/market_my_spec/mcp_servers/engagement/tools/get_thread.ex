defmodule MarketMySpec.McpServers.Engagement.Tools.GetThread do
  @moduledoc """
  MCP tool: fetch (and optionally refresh) a persisted Thread by UUID.

  Looks up the Thread by UUID within the caller's account scope. If the
  Thread's `fetched_at` is within the 5-minute freshness window, returns
  the cached row. Otherwise re-fetches from Reddit's `/comments/<id>.json`
  endpoint, updates the existing row in place (same UUID), and returns
  the updated Thread.

  On refresh failure (HTTP 429 / 5xx / network error), the persisted row
  is preserved unchanged and the response includes a `stale_warning` map
  with `reason` and `age_seconds`.

  When Reddit returns HTTP 200 but the comment payload fails to normalize,
  `raw_payload` and `fetched_at` are written but `comment_tree` falls back
  to its prior value. A `normalization_error` key is included in the response.

  Cross-account access (UUID belongs to a different account) returns an
  error response without leaking Thread data or making any HTTP call.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Thread
  alias MarketMySpec.Engagements.ThreadsRepository
  alias MarketMySpec.Repo

  @freshness_window_seconds 300

  schema do
    field :thread_id, :string, required: true, doc: "Thread UUID (stable UUID from search_engagements)"
    field :comments_cursor, :string, required: false, doc: "Pagination cursor for next page of comments"
  end

  @impl true
  def execute(%{thread_id: thread_id} = params, frame) do
    scope = frame.assigns.current_scope
    cursor = Map.get(params, :comments_cursor)

    case ThreadsRepository.get_thread_by_id(scope, thread_id) do
      {:error, :not_found} ->
        {:reply, Response.tool() |> Response.error("Thread not found: #{thread_id}"), frame}

      {:ok, thread} ->
        if fresh?(thread) and is_nil(cursor) do
          payload = encode_thread(thread, nil, nil)
          {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}
        else
          refresh_thread(thread, scope, cursor, frame)
        end
    end
  end

  # A thread is considered "fresh" (no re-fetch needed) only when:
  # 1. fetched_at is set (the deep-read has happened at least once), AND
  # 2. op_body is populated (content was normalized), AND
  # 3. fetched_at is within the freshness window.
  #
  # A thread upserted from search has fetched_at = nil and op_body = nil.
  # Calling get_thread on such a thread must always trigger a deep-read.
  defp fresh?(%Thread{fetched_at: nil}), do: false
  defp fresh?(%Thread{op_body: op_body}) when is_nil(op_body), do: false
  defp fresh?(%Thread{op_body: ""}), do: false

  defp fresh?(%Thread{fetched_at: fetched_at}) do
    age = DateTime.diff(DateTime.utc_now(), fetched_at, :second)
    age < @freshness_window_seconds
  end

  defp refresh_thread(thread, scope, cursor, frame) do
    opts = if cursor, do: [after: cursor], else: []

    case Reddit.get_thread(nil, thread.source_thread_id, opts) do
      {:ok, raw} ->
        {updated_thread, norm_error} = persist_refresh(thread, raw, scope)
        cursor_out = Map.get(raw, :comments_cursor)
        payload = encode_thread(updated_thread, cursor_out, norm_error)
        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}

      {:error, reason} ->
        age = stale_age(thread)

        payload = encode_thread(thread, nil, nil)
        |> Map.put("stale_warning", %{
          "reason" => stale_reason_string(reason),
          "age_seconds" => age
        })

        {:reply, Response.tool() |> Response.text(Jason.encode!(payload)), frame}
    end
  end

  defp persist_refresh(thread, raw, _scope) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    prior_tree = thread.comment_tree
    raw_payload = Map.get(raw, :raw_payload, %{})
    new_comment_tree = Map.get(raw, :comment_tree)
    norm_error = Map.get(raw, :normalization_error)
    last_activity_at = Map.get(raw, :last_activity_at)
    op_body = Map.get(raw, :op_body, thread.op_body || "")

    # If normalization errored, keep prior comment_tree
    comment_tree =
      if norm_error do
        prior_tree
      else
        new_comment_tree || prior_tree
      end

    attrs = %{
      op_body: op_body,
      comment_tree: comment_tree || %{},
      raw_payload: raw_payload,
      fetched_at: now,
      last_activity_at: last_activity_at
    }

    updated =
      thread
      |> Thread.changeset(attrs)
      |> Repo.update!()

    {updated, norm_error}
  end

  defp stale_age(%Thread{fetched_at: nil}), do: 0

  defp stale_age(%Thread{fetched_at: fetched_at}) do
    DateTime.diff(DateTime.utc_now(), fetched_at, :second)
  end

  defp stale_reason_string({:http_status, 429}), do: "rate_limited"
  defp stale_reason_string({:http_status, status}), do: "http_#{status}"
  defp stale_reason_string(_), do: "network_error"

  defp encode_thread(%Thread{} = thread, cursor, norm_error) do
    base = %{
      "thread" => %{
        "id" => thread.id,
        "source" => to_string(thread.source),
        "source_thread_id" => thread.source_thread_id,
        "title" => thread.title,
        "url" => thread.url,
        "op_body" => thread.op_body,
        "comment_tree" => thread.comment_tree,
        "raw_payload" => thread.raw_payload,
        "fetched_at" => thread.fetched_at && DateTime.to_iso8601(thread.fetched_at),
        "last_activity_at" =>
          thread.last_activity_at && DateTime.to_iso8601(thread.last_activity_at),
        "inserted_at" => thread.inserted_at && DateTime.to_iso8601(thread.inserted_at)
      },
      "comments_cursor" => cursor
    }

    base =
      if norm_error do
        Map.put(base, "normalization_error", norm_error)
      else
        base
      end

    base
  end
end
