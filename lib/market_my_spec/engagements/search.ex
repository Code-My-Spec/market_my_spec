defmodule MarketMySpec.Engagements.Search do
  @moduledoc """
  Engagement search orchestrator.

  Reads the account's enabled venues via VenuesRepository, fans out to each
  Source adapter's search/2 in parallel (one task per venue), deduplicates
  results by URL, and ranks the unified candidate list by
  `venue.weight × per-source signal` descending.

  Failing source calls degrade gracefully — healthy venues still contribute
  their candidates, and each failure is collected into the `failures` field
  of the result envelope so callers (LLM or UI) can surface which venues
  errored without crashing the whole call.
  """

  alias MarketMySpec.Engagements.Source.ElixirForum
  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.VenuesRepository
  alias MarketMySpec.Users.Scope

  @type candidate :: map()

  @type result :: %{
          candidates: [candidate()],
          failures: [%{venue: map(), reason: term()}],
          next_cursor: nil | String.t()
        }

  @doc """
  Fans out the keyword `query` to all enabled venues in the account's scope.

  Accepts opts:
  - `:venue` — restrict to a single venue identifier
  - `:cursor` — pagination cursor passed through to each adapter (Reddit's
    `after` parameter). Single-venue pagination is well-defined;
    multi-venue pagination returns the first non-nil cursor it sees (v1
    limitation — to be revisited if multi-venue pagination becomes a
    real workflow).

  Returns a map with:
  - `:candidates` — deduplicated list ranked by `venue.weight × signal` descending
  - `:failures` — list of `%{venue: venue, reason: reason}` for source errors
  - `:next_cursor` — opaque pagination token (or `nil` at end of listing)
  """
  @spec search(Scope.t(), String.t(), keyword()) :: result()
  def search(%Scope{} = scope, query, opts \\ []) when is_binary(query) do
    venue_filter = Keyword.get(opts, :venue, nil)
    cursor = Keyword.get(opts, :cursor, nil)

    venues =
      scope
      |> VenuesRepository.list_venues()
      |> Enum.filter(& &1.enabled)
      |> maybe_filter_venue(venue_filter)

    {candidates, failures, next_cursor} = fan_out(venues, query, cursor)

    ranked =
      candidates
      |> deduplicate()
      |> rank()

    %{candidates: ranked, failures: failures, next_cursor: next_cursor}
  end

  # Fan out to each venue in parallel via Task.async_stream.
  # Each adapter returns either `{:ok, %{candidates: [...], next_cursor: ...}}`
  # or `{:error, reason}`. We collect candidates, failures, and the first
  # non-nil per-venue cursor (single-venue pagination is the v1 use case).
  defp fan_out(venues, query, cursor) do
    venues
    |> Task.async_stream(
      fn venue -> {venue, search_venue(venue, query, cursor)} end,
      on_timeout: :kill_task,
      timeout: 15_000
    )
    |> Enum.reduce({[], [], nil}, fn
      {:ok, {venue, {:ok, %{candidates: raw_candidates, next_cursor: nc}}}},
      {acc_candidates, acc_failures, acc_cursor} ->
        weighted = Enum.map(raw_candidates, &attach_weight(&1, venue.weight))
        {acc_candidates ++ weighted, acc_failures, acc_cursor || nc}

      {:ok, {venue, {:error, reason}}}, {acc_candidates, acc_failures, acc_cursor} ->
        failure = %{venue: venue, reason: reason}
        {acc_candidates, acc_failures ++ [failure], acc_cursor}

      {:exit, reason}, {acc_candidates, acc_failures, acc_cursor} ->
        failure = %{venue: nil, reason: {:task_exit, reason}}
        {acc_candidates, acc_failures ++ [failure], acc_cursor}
    end)
  end

  defp search_venue(venue, query, cursor) do
    adapter = adapter_for(venue.source)
    adapter.search(venue, query, cursor: cursor)
  rescue
    error -> {:error, error}
  end

  # Attach the venue weight so the ranking step can multiply against it.
  defp attach_weight(candidate, weight) do
    Map.put(candidate, "_venue_weight", weight)
  end

  # Deduplicate by URL. First occurrence wins.
  defp deduplicate(candidates) do
    candidates
    |> Enum.uniq_by(fn c -> Map.get(c, "url") || Map.get(c, :url) end)
  end

  # Rank by venue.weight × per-source signal (score field) descending.
  # Falls back to 0 when signal fields are absent (stub adapters).
  defp rank(candidates) do
    candidates
    |> Enum.map(&compute_rank/1)
    |> Enum.sort_by(& &1["rank"], :desc)
  end

  defp compute_rank(candidate) do
    weight = Map.get(candidate, "_venue_weight", 1.0)
    signal = extract_signal(candidate)
    rank_score = weight * signal

    candidate
    |> Map.delete("_venue_weight")
    |> Map.put("rank", rank_score)
  end

  defp extract_signal(candidate) do
    score = Map.get(candidate, "score") || Map.get(candidate, :score) || 0
    reply_count = Map.get(candidate, "reply_count") || Map.get(candidate, :reply_count) || 0

    score_f = to_float(score)
    reply_f = to_float(reply_count)

    # Simple composite: score + 0.5 × reply_count (gives weight to engagement)
    score_f + 0.5 * reply_f
  end

  defp to_float(val) when is_integer(val), do: val * 1.0
  defp to_float(val) when is_float(val), do: val
  defp to_float(_), do: 0.0

  defp adapter_for(:reddit), do: Reddit
  defp adapter_for(:elixirforum), do: ElixirForum

  defp maybe_filter_venue(venues, nil), do: venues

  defp maybe_filter_venue(venues, identifier) when is_binary(identifier) do
    Enum.filter(venues, fn v -> v.identifier == identifier end)
  end
end
