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

  ## Two execution models, by source

  ElixirForum is fetched live — its API has no meaningful per-IP budget, so
  a search hits it and returns.

  Reddit is **queued**. Reddit meters anonymous RSS at roughly one request
  per 60s per IP (measured live; see `Engagements.RateLimiter`), which is
  far too slow to fan out across venues inside a tool call. So a Reddit
  venue is served from the last completed fetch in
  `Engagements.RedditFetchQueue` while a refresh is enqueued for the paired
  agent to run in the background. Callers get results immediately; those
  results are as fresh as the last drain, and `notices` says so.

  This means a first-ever search on a venue legitimately returns zero
  candidates with a "queued" notice rather than an error — the data will be
  there on the next call.

  ## Failure envelope shape

  Each failure entry carries flat keys:
  - `source` — the source atom (`:reddit`, `:elixirforum`)
  - `venue_identifier` — the venue identifier string (e.g. `"elixir"`)
  - `reason` — a human-readable string describing the failure
  """

  alias MarketMySpec.Engagements.RedditFetchQueue
  alias MarketMySpec.Engagements.RedditFetchQueue.Drain
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
          notices: [String.t()],
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
  - `:notices` — informational strings (e.g. agent-offline fallback notice)
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

    {venue_candidates, failures, notices, next_cursor} = fan_out(venues, query, cursor, scope)

    ranked =
      venue_candidates
      |> deduplicate_across_venues()
      |> interleave_by_weight()
      |> persist_and_enrich(scope)

    %{
      candidates: ranked,
      failures: failures,
      notices: notices ++ rate_limit_notices(failures) ++ queue_notices(scope),
      next_cursor: next_cursor
    }
  end

  # One line summarizing outstanding Reddit work, so a caller looking at a
  # thin result set can tell the difference between "Reddit is quiet" and
  # "six fetches are still waiting their turn".
  defp queue_notices(scope) do
    case RedditFetchQueue.pending_count(scope) do
      0 ->
        []

      count ->
        [
          "#{count} Reddit #{fetch_word(count)} queued (~1/minute via the MMS Agent). " <>
            "Re-run in a few minutes for fresher results."
        ]
    end
  end

  defp fetch_word(1), do: "fetch"
  defp fetch_word(_), do: "fetches"

  @doc """
  Builds operator-facing notices from a `failures` list.

  When one or more venues were throttled (Reddit rate limit), returns a single
  notice telling the operator the empty/partial result is a throttle, not an
  absence of fresh threads — so a zero-candidate run isn't misread as "nothing
  to engage." Returns `[]` when no failures were rate-limit related.

  Public so the saved-search fan-out (which aggregates failures across several
  single-venue searches) can emit the same notice from its combined list.
  """
  @spec rate_limit_notices([failure()]) :: [String.t()]
  def rate_limit_notices(failures) do
    case Enum.count(failures, &rate_limited?/1) do
      0 ->
        []

      count ->
        [
          "#{count} #{venue_word(count)} throttled (Reddit rate limit). " <>
            "Wait ~2-3 minutes and re-run, or run fewer searches in parallel."
        ]
    end
  end

  defp rate_limited?(%{reason: "Rate limited" <> _}), do: true
  defp rate_limited?(_), do: false

  defp venue_word(1), do: "venue was"
  defp venue_word(_), do: "venues were"

  # Fan out to each venue in parallel via Task.async_stream.
  # Each venue returns `{:ok, %{candidates: [...], next_cursor: ...}}`,
  # `{:error, reason}`, or `{:pending, message}` (Reddit venue whose first
  # fetch hasn't drained yet). We collect per-venue candidate lists (keeping
  # venue metadata attached for interleaving), failures, informational
  # notices, and the first non-nil cursor.
  defp fan_out(venues, query, cursor, scope) do
    venues
    |> Task.async_stream(
      fn venue -> {venue, search_venue(venue, query, cursor, scope)} end,
      on_timeout: :kill_task,
      timeout: 15_000
    )
    |> Enum.reduce({[], [], [], nil}, fn
      {:ok, {venue, {:ok, %{candidates: raw_candidates, next_cursor: nc} = result}}},
      {acc_venue_lists, acc_failures, acc_notices, acc_cursor} ->
        venue_entry = {venue, raw_candidates}
        notices = acc_notices ++ staleness_notice(venue, result)
        {acc_venue_lists ++ [venue_entry], acc_failures, notices, acc_cursor || nc}

      {:ok, {venue, {:pending, message}}},
      {acc_venue_lists, acc_failures, acc_notices, acc_cursor} ->
        # Not a failure: the work is queued and will land. Still contribute
        # an (empty) venue entry so weighting/interleaving see the venue.
        {acc_venue_lists ++ [{venue, []}], acc_failures, acc_notices ++ [message], acc_cursor}

      {:ok, {venue, {:error, reason}}}, {acc_venue_lists, acc_failures, acc_notices, acc_cursor} ->
        failure = %{
          source: venue.source,
          venue_identifier: venue.identifier,
          reason: format_reason(venue.source, reason)
        }

        {acc_venue_lists, acc_failures ++ [failure], acc_notices, acc_cursor}

      {:exit, reason}, {acc_venue_lists, acc_failures, acc_notices, acc_cursor} ->
        failure = %{
          source: nil,
          venue_identifier: nil,
          reason: "Task exited: #{inspect(reason)}"
        }

        {acc_venue_lists, acc_failures ++ [failure], acc_notices, acc_cursor}
    end)
  end

  # Reddit goes through the queue; every other source is fetched live.
  defp search_venue(%{source: :reddit} = venue, query, cursor, scope),
    do: search_reddit_venue(venue, query, cursor, scope)

  defp search_venue(venue, query, cursor, _scope) do
    adapter = adapter_for(venue.source)
    adapter.search(venue, query, cursor: cursor)
  rescue
    error -> {:error, error}
  end

  # Enqueue a refresh, then serve whatever the last completed fetch found.
  # Enqueue-then-read (not read-then-enqueue) so a caller who sees stale
  # data knows a refresh is already in flight for it.
  defp search_reddit_venue(venue, query, cursor, scope) do
    RedditFetchQueue.enqueue_search(scope, venue, query, cursor: cursor)
    Drain.kick()

    case RedditFetchQueue.latest_completed_search(scope, venue, query) do
      %{candidates: candidates} = job when is_list(candidates) ->
        {:ok,
         %{
           candidates: candidates,
           next_cursor: job.next_cursor,
           fetched_at: job.completed_at
         }}

      _ ->
        pending_or_failed(scope, venue, query)
    end
  rescue
    error -> {:error, error}
  end

  # No completed fetch yet. If the most recent attempt failed, that's a real
  # failure the caller should see; otherwise it's simply still queued.
  defp pending_or_failed(scope, venue, query) do
    case RedditFetchQueue.latest_failure(scope, venue, query) do
      nil ->
        {:pending,
         "r/#{venue.identifier}: first fetch queued — results appear once the agent runs it " <>
           "(Reddit allows ~1 request/minute)."}

      job ->
        {:error, {:last_fetch_failed, job.last_error}}
    end
  end

  # Tell the caller how old the served results are, so zero-or-few candidates
  # is never silently misread as "nothing out there right now".
  defp staleness_notice(%{source: :reddit} = venue, %{fetched_at: %DateTime{} = fetched_at}) do
    ["r/#{venue.identifier}: results from #{format_age(fetched_at)}; refresh queued."]
  end

  defp staleness_notice(_venue, _result), do: []

  defp format_age(%DateTime{} = at) do
    case DateTime.diff(DateTime.utc_now(), at, :second) do
      s when s < 90 -> "just now"
      s when s < 3_600 -> "#{div(s, 60)}m ago"
      s when s < 86_400 -> "#{div(s, 3_600)}h ago"
      s -> "#{div(s, 86_400)}d ago"
    end
  end

  # Format a failure reason into a human-readable string.
  defp format_reason(:reddit, {:last_fetch_failed, reason}),
    do: "Last queued fetch failed: #{reason || "unknown error"}"

  defp format_reason(_source, {:agent_error, reason}),
    do: "MMS Agent could not complete the fetch: #{reason}"

  defp format_reason(_source, :agent_offline),
    do: "No online MMS Agent. Pair or start an agent at /app/agents."

  defp format_reason(_source, {:http_status, 429}),
    do: "Rate limited (HTTP 429 Too Many Requests)"

  defp format_reason(_source, :rate_limit_timeout),
    do: "Rate limited (throttled locally to stay under the source's limit; try again shortly)"

  defp format_reason(_source, {:http_status, status}),
    do: "HTTP error #{status}"

  defp format_reason(_source, reason) when is_binary(reason), do: reason

  defp format_reason(_source, reason), do: inspect(reason)

  # Deduplicate by URL across all venue lists, keeping per-venue structure.
  # Returns a list of {venue, candidates} where candidates have been deduped
  # globally (first occurrence wins).
  defp deduplicate_across_venues(venue_candidate_lists) do
    {deduped_lists, _seen} =
      Enum.map_reduce(venue_candidate_lists, MapSet.new(), &dedup_venue/2)

    deduped_lists
  end

  defp dedup_venue({venue, candidates}, seen) do
    {unique, new_seen} = Enum.reduce(candidates, {[], seen}, &dedup_candidate/2)
    {{venue, unique}, new_seen}
  end

  defp dedup_candidate(candidate, {acc, seen_acc}) do
    url = Map.get(candidate, "url") || Map.get(candidate, :url)

    cond do
      url && MapSet.member?(seen_acc, url) -> {acc, seen_acc}
      url -> {acc ++ [candidate], MapSet.put(seen_acc, url)}
      true -> {acc ++ [candidate], seen_acc}
    end
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
      _remaining = Enum.reject(tails, &(&1 == []))
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
