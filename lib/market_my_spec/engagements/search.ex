defmodule MarketMySpec.Engagements.Search do
  @moduledoc """
  Engagement search orchestrator.

  Reads the account's enabled venues via VenuesRepository, fans out to each
  Source adapter's search/2 in parallel (one task per venue), deduplicates
  results by URL, and interleaves the unified candidate list by
  round-robin across venues ordered by `venue.weight` descending.

  Failing source calls degrade gracefully — healthy venues still contribute
  their candidates, and each failure is collected into the `failures` field
  of the result envelope so callers (LLM or UI) can surface which venues
  errored without crashing the whole call.

  ## Failure envelope shape

  Each failure entry carries flat keys:
  - `source` — the source atom (`:reddit`, `:elixirforum`)
  - `venue_identifier` — the venue identifier string (e.g. `"elixir"`)
  - `reason` — a human-readable string describing the failure
  """

  alias MarketMySpec.Engagements.Source.ElixirForum
  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.ThreadsRepository
  alias MarketMySpec.Engagements.TouchpointsRepository
  alias MarketMySpec.Engagements.VenuesRepository
  alias MarketMySpec.Users.Scope

  @type candidate :: map()

  @type failure :: %{
          source: atom(),
          venue_identifier: String.t(),
          reason: String.t()
        }

  @type result :: %{
          candidates: [candidate()],
          failures: [failure()],
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
  - `:candidates` — deduplicated list interleaved by venue weight descending
  - `:failures` — list of `%{source, venue_identifier, reason}` for source errors
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

    {venue_candidates, failures, next_cursor} = fan_out(venues, query, cursor)

    ranked =
      venue_candidates
      |> deduplicate_across_venues()
      |> interleave_by_weight()
      |> persist_and_enrich(scope)

    %{candidates: ranked, failures: failures, next_cursor: next_cursor}
  end

  # Fan out to each venue in parallel via Task.async_stream.
  # Each adapter returns either `{:ok, %{candidates: [...], next_cursor: ...}}`
  # or `{:error, reason}`. We collect per-venue candidate lists (keeping venue
  # metadata attached for interleaving), failures, and the first non-nil cursor.
  defp fan_out(venues, query, cursor) do
    venues
    |> Task.async_stream(
      fn venue -> {venue, search_venue(venue, query, cursor)} end,
      on_timeout: :kill_task,
      timeout: 15_000
    )
    |> Enum.reduce({[], [], nil}, fn
      {:ok, {venue, {:ok, %{candidates: raw_candidates, next_cursor: nc}}}},
      {acc_venue_lists, acc_failures, acc_cursor} ->
        venue_entry = {venue, raw_candidates}
        {acc_venue_lists ++ [venue_entry], acc_failures, acc_cursor || nc}

      {:ok, {venue, {:error, reason}}}, {acc_venue_lists, acc_failures, acc_cursor} ->
        failure = %{
          source: venue.source,
          venue_identifier: venue.identifier,
          reason: format_reason(venue.source, reason)
        }

        {acc_venue_lists, acc_failures ++ [failure], acc_cursor}

      {:exit, reason}, {acc_venue_lists, acc_failures, acc_cursor} ->
        failure = %{
          source: nil,
          venue_identifier: nil,
          reason: "Task exited: #{inspect(reason)}"
        }

        {acc_venue_lists, acc_failures ++ [failure], acc_cursor}
    end)
  end

  defp search_venue(venue, query, cursor) do
    adapter = adapter_for(venue.source)
    adapter.search(venue, query, cursor: cursor)
  rescue
    error -> {:error, error}
  end

  # Format a failure reason into a human-readable string.
  defp format_reason(_source, {:http_status, 429}),
    do: "Rate limited (HTTP 429 Too Many Requests)"

  defp format_reason(_source, {:http_status, status}),
    do: "HTTP error #{status}"

  defp format_reason(_source, reason) when is_binary(reason), do: reason

  defp format_reason(_source, reason), do: inspect(reason)

  # Deduplicate by URL across all venue lists, keeping per-venue structure.
  # Returns a list of {venue, candidates} where candidates have been deduped
  # globally (first occurrence wins).
  defp deduplicate_across_venues(venue_candidate_lists) do
    {deduped_lists, _seen} =
      Enum.map_reduce(venue_candidate_lists, MapSet.new(), fn {venue, candidates}, seen ->
        {unique, new_seen} =
          Enum.reduce(candidates, {[], seen}, fn c, {acc, seen_acc} ->
            url = Map.get(c, "url") || Map.get(c, :url)

            if url && MapSet.member?(seen_acc, url) do
              {acc, seen_acc}
            else
              new_seen_acc = if url, do: MapSet.put(seen_acc, url), else: seen_acc
              {acc ++ [c], new_seen_acc}
            end
          end)

        {{venue, unique}, new_seen}
      end)

    deduped_lists
  end

  # Interleave per-venue candidate lists by round-robin, with venues ordered
  # by weight descending. Within each venue list, candidates are already in
  # per-source ranked order (adapters return them ranked).
  #
  # Example: venues A (weight=1.0, [A1, A2, A3]) and B (weight=0.5, [B1, B2])
  # produces [A1, B1, A2, B2, A3] — alternating with A first (higher weight).
  defp interleave_by_weight(venue_candidate_lists) do
    # Sort venue lists by weight descending so highest-weight source goes first
    # in each round of the interleave.
    sorted_lists =
      venue_candidate_lists
      |> Enum.map(fn {venue, candidates} -> {venue.weight, candidates} end)
      |> Enum.sort_by(fn {weight, _} -> weight end, :desc)
      |> Enum.map(fn {_weight, candidates} -> candidates end)

    do_interleave(sorted_lists, [])
  end

  defp do_interleave(lists, acc) do
    # Take the first candidate from each non-empty list, in weight order.
    {heads, tails} =
      Enum.reduce(lists, {[], []}, fn
        [], {hs, ts} -> {hs, ts ++ [[]]}
        [h | t], {hs, ts} -> {hs ++ [h], ts ++ [t]}
      end)

    if heads == [] do
      Enum.reverse(acc)
    else
      remaining = Enum.reject(tails, &(&1 == []))
      non_empty_tails = tails

      do_interleave(non_empty_tails, Enum.reverse(heads) ++ acc)
    end
  end

  defp adapter_for(:reddit), do: Reddit
  defp adapter_for(:elixirforum), do: ElixirForum

  defp maybe_filter_venue(venues, nil), do: venues

  defp maybe_filter_venue(venues, identifier) when is_binary(identifier) do
    Enum.filter(venues, fn v -> v.identifier == identifier end)
  end

  # For each ranked candidate: upsert a Thread row keyed by
  # (account_id, source, source_thread_id), then replace the candidate's
  # `recency` field with the persisted Thread's recency (last_activity_at
  # when set, else inserted_at), attach the stable `thread_id` UUID, and
  # attach the `engagement` summary.
  defp persist_and_enrich(candidates, scope) do
    Enum.map(candidates, fn candidate ->
      source = parse_source(Map.get(candidate, "source"))

      case ThreadsRepository.upsert_from_search(scope, source, candidate) do
        {:ok, thread} ->
          engagement =
            TouchpointsRepository.engagement_summary(
              scope.active_account_id,
              thread.id
            )

          recency =
            if thread.last_activity_at do
              DateTime.to_iso8601(thread.last_activity_at)
            else
              DateTime.to_iso8601(thread.inserted_at)
            end

          candidate
          |> Map.put("thread_id", thread.id)
          |> Map.put("recency", recency)
          |> Map.put("engagement", engagement)

        {:error, _reason} ->
          # Upsert failed (e.g. missing source_thread_id caught by changeset).
          # Silently drop the candidate — malformed entries do not appear.
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_source("reddit"), do: :reddit
  defp parse_source("elixirforum"), do: :elixirforum
  defp parse_source(atom) when is_atom(atom), do: atom
end
