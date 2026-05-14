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
          failures: [%{venue: map(), reason: term()}]
        }

  @doc """
  Fans out the keyword `query` to all enabled venues in the account's scope.

  Accepts an optional `venue` identifier string to restrict search to a single
  venue (matched by identifier). When omitted, all enabled venues are searched.

  Returns a map with:
  - `:candidates` — deduplicated list ranked by `venue.weight × signal` descending
  - `:failures` — list of `%{venue: venue, reason: reason}` for source errors
  """
  @spec search(Scope.t(), String.t(), keyword()) :: result()
  def search(%Scope{} = scope, query, opts \\ []) when is_binary(query) do
    venue_filter = Keyword.get(opts, :venue, nil)

    venues =
      scope
      |> VenuesRepository.list_venues()
      |> Enum.filter(& &1.enabled)
      |> maybe_filter_venue(venue_filter)

    {candidates, failures} = fan_out(venues, query)

    ranked =
      candidates
      |> deduplicate()
      |> rank()

    %{candidates: ranked, failures: failures}
  end

  # Fan out to each venue in parallel via Task.async_stream.
  # Each result is either {:ok, [candidate]} or {:error, reason}.
  # We collect both, never letting a single failure abort the stream.
  defp fan_out(venues, query) do
    venues
    |> Task.async_stream(
      fn venue -> {venue, search_venue(venue, query)} end,
      on_timeout: :kill_task,
      timeout: 15_000
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {venue, {:ok, raw_candidates}}}, {acc_candidates, acc_failures} ->
        weighted = Enum.map(raw_candidates, &attach_weight(&1, venue.weight))
        {acc_candidates ++ weighted, acc_failures}

      {:ok, {venue, {:error, reason}}}, {acc_candidates, acc_failures} ->
        failure = %{venue: venue, reason: reason}
        {acc_candidates, acc_failures ++ [failure]}

      {:exit, reason}, {acc_candidates, acc_failures} ->
        failure = %{venue: nil, reason: {:task_exit, reason}}
        {acc_candidates, acc_failures ++ [failure]}
    end)
  end

  defp search_venue(venue, query) do
    adapter = adapter_for(venue.source)
    adapter.search(venue, query)
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
