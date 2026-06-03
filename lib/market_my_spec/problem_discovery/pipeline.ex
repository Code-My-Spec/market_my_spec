defmodule MarketMySpec.ProblemDiscovery.Pipeline do
  @moduledoc """
  Stage orchestration for ProblemDiscovery.

  Each stage reads its upstream artifacts, runs the stage logic, and
  persists outputs. Enforces additive Gather (per-saved-search),
  in-place reclassification on Score reruns (story 743 rule 8),
  overwrite-no-history semantics throughout, and the Path C split
  between MMS's mechanical clustering and the agent's semantic
  refinement (`problem-discovery-clustering.md`).

  The stages are independent — each one reads from the database and
  writes back. The agent invokes them via the corresponding MCP tools
  (`RunGather`, `RunCluster`, `RunScore`, `RedTeamCandidate`).
  """

  import Ecto.Query

  alias MarketMySpec.ProblemDiscovery.Candidate
  alias MarketMySpec.ProblemDiscovery.Clustering
  alias MarketMySpec.ProblemDiscovery.Embeddings
  alias MarketMySpec.ProblemDiscovery.Frame
  alias MarketMySpec.ProblemDiscovery.JobPosting
  alias MarketMySpec.ProblemDiscovery.PaidJobSignal
  alias MarketMySpec.ProblemDiscovery.RedTeamVerdict
  alias MarketMySpec.ProblemDiscovery.Source
  alias MarketMySpec.Repo

  @doc """
  Probe-mode Gather: return a sample of postings for a draft (uncommitted)
  Frame without persisting anything. Used by Frame composition to validate
  saved searches before committing the Frame (criterion 6580).
  """
  @spec probe(map(), keyword()) ::
          {:ok, %{sample: [map()], persisted: false}} | {:error, term()}
  def probe(%{saved_searches: searches}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    sample =
      searches
      |> Enum.flat_map(fn saved_search ->
        case Source.search(saved_search, limit: limit) do
          {:ok, postings} -> postings
          {:error, _} -> []
        end
      end)

    {:ok, %{sample: sample, persisted: false}}
  end

  @doc """
  Gather stage. Per-saved-search execution; additive (only gathers
  saved-search indexes that have no JobPostings yet). Embeds each
  posting on insert via `Embeddings.embed_batch/1`.

  Returns per-saved-search counts: `[%{index: i, gathered: n, failed: m}, ...]`.
  """
  @spec gather(Ecto.UUID.t(), keyword()) ::
          {:ok, %{per_saved_search: list()}} | {:error, term()}
  def gather(frame_id, opts \\ []) when is_binary(frame_id) do
    case Repo.get(Frame, frame_id) do
      nil -> {:error, :not_found}
      %Frame{} = frame -> {:ok, %{per_saved_search: gather_each(frame, opts)}}
    end
  end

  defp gather_each(%Frame{} = frame, opts) do
    force = Keyword.get(opts, :force, false)

    frame.saved_searches
    |> Enum.with_index()
    |> Enum.map(fn {saved_search, index} ->
      gather_or_skip(frame, index, saved_search, force, opts)
    end)
  end

  defp gather_or_skip(frame, index, saved_search, force, opts) do
    if force or not already_gathered?(saved_search) do
      result = gather_one(frame, index, saved_search, opts)
      mark_if_attempted(result, frame, index)
      result
    else
      %{index: index, gathered: 0, failed: 0, skipped: true}
    end
  end

  # Only mark the saved_search as gathered when the adapter actually
  # made the call AND it produced rows. Pre-request failures (e.g.
  # :missing_upwork_api_key, network error) AND zero-result responses
  # both leave the search unmarked so the next RunGather retries
  # without `--force`. A locked zero-result query masks the difference
  # between "this market genuinely has no demand" (a real MMS finding)
  # and "this query was malformed" (a fixable problem) — both would
  # appear as a 0-row corpus permanently. See per-saved-search return
  # in `gather_one/4` for the `zero_results: true` marker the agent
  # sees in the payload.
  defp mark_if_attempted(%{error: _}, _frame, _index), do: :noop
  defp mark_if_attempted(%{zero_results: true}, _frame, _index), do: :noop
  defp mark_if_attempted(_result, frame, index), do: mark_saved_search_gathered(frame, index)

  defp already_gathered?(%{"gathered_at" => ts}) when is_binary(ts), do: true
  defp already_gathered?(%{gathered_at: ts}) when is_binary(ts), do: true
  defp already_gathered?(_), do: false

  defp mark_saved_search_gathered(%Frame{id: frame_id}, index) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    fresh = Repo.get!(Frame, frame_id)

    updated =
      fresh.saved_searches
      |> List.update_at(index, fn entry ->
        entry
        |> stringify_keys()
        |> Map.put("gathered_at", now)
      end)

    fresh
    |> Ecto.Changeset.change(saved_searches: updated)
    |> Repo.update!()
  end

  defp stringify_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp gather_one(%Frame{} = frame, index, saved_search, opts) do
    saved_search = normalize_saved_search(saved_search)

    with {:ok, postings} <- Source.search(saved_search, opts),
         {:ok, with_embeddings} <- attach_embeddings(postings, opts) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {inserted, failed} = insert_postings(with_embeddings, frame.id, index, now)
      base = %{index: index, gathered: inserted, failed: failed}

      # Surface a zero_results signal so the agent can tell "0 because
      # the query was malformed" from "0 because demand is genuinely
      # absent" — the second is a real MMS finding. Pairs with the
      # mark_if_attempted/3 rule that leaves zero-result searches
      # unlocked for refine-and-retry.
      if inserted == 0, do: Map.put(base, :zero_results, true), else: base
    else
      {:error, reason} -> %{index: index, gathered: 0, failed: 1, error: inspect(reason)}
    end
  end

  defp insert_postings(postings, frame_id, index, now) do
    Enum.reduce(postings, {0, 0}, &insert_one_posting(&1, frame_id, index, now, &2))
  end

  defp insert_one_posting(posting, frame_id, index, now, {ok, bad}) do
    attrs =
      Map.merge(posting, %{
        frame_id: frame_id,
        saved_search_index: index,
        gathered_at: now
      })

    case Repo.insert(JobPosting.changeset(%JobPosting{}, attrs)) do
      {:ok, _} -> {ok + 1, bad}
      {:error, _} -> {ok, bad + 1}
    end
  end

  defp normalize_saved_search(%{"source" => s, "query" => q}), do: %{source: s, query: q}
  defp normalize_saved_search(%{source: _, query: _} = ss), do: ss

  defp attach_embeddings([], _opts), do: {:ok, []}

  defp attach_embeddings(postings, opts) do
    texts = Enum.map(postings, &posting_text/1)
    embed_fn = embed_fn(opts)

    with {:ok, vectors} <- embed_fn.(texts, opts) do
      paired =
        postings
        |> Enum.zip(vectors)
        |> Enum.map(fn {posting, vector} -> Map.put(posting, :embedding, vector) end)

      {:ok, paired}
    end
  end

  # Test override hook — Application config can point at a stub fn so
  # tests don't need a working OpenAI key. Defaults to the real
  # Embeddings.embed_batch/2 in dev / prod.
  defp embed_fn(opts) do
    Keyword.get(opts, :embed_fn) ||
      Application.get_env(:market_my_spec, :embeddings_embed_fn) ||
      (&Embeddings.embed_batch/2)
  end

  defp posting_text(%{title: title, description: description}),
    do: "#{title}\n\n#{description}"

  @doc """
  Cluster stage. Reads JobPosting embeddings for the Frame, runs one
  KMeans pass (via Clustering), persists fresh Candidates with mean-of-
  members centroids, and assigns `candidate_id` on each JobPosting.

  Overwrite semantics: existing Candidates and their PaidJobSignals and
  RedTeamVerdicts are deleted before insertion of the fresh partition.
  Identity stability across reruns when the input set is unchanged comes
  from the deterministic KMeans seed in Clustering.
  """
  @spec cluster(Ecto.UUID.t(), keyword()) ::
          {:ok, %{candidate_count: non_neg_integer()}} | {:error, term()}
  def cluster(frame_id, opts \\ []) when is_binary(frame_id) do
    postings =
      Repo.all(
        from(jp in JobPosting,
          where: jp.frame_id == ^frame_id,
          order_by: [asc: jp.source, asc: jp.source_id]
        )
      )

    case postings do
      [] ->
        {:error, :empty_upstream}

      _ ->
        embeddings = Enum.map(postings, &Pgvector.to_list(&1.embedding))

        with {:ok, %{assignments: assignments, centroids: centroids}} <-
               Clustering.cluster(embeddings, opts) do
          persist_clusters(frame_id, postings, assignments, centroids)
        end
    end
  end

  defp persist_clusters(frame_id, postings, assignments, centroids) do
    Repo.delete_all(from(c in Candidate, where: c.frame_id == ^frame_id))

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    candidate_ids =
      centroids
      |> Enum.map(fn centroid ->
        {:ok, candidate} =
          Repo.insert(
            Candidate.changeset(%Candidate{}, %{
              frame_id: frame_id,
              centroid: Pgvector.new(centroid)
            })
            |> Ecto.Changeset.put_change(:inserted_at, now)
            |> Ecto.Changeset.put_change(:updated_at, now)
          )

        candidate.id
      end)

    postings
    |> Enum.zip(assignments)
    |> Enum.each(fn {posting, cluster_idx} ->
      candidate_id = Enum.at(candidate_ids, cluster_idx)

      posting
      |> Ecto.Changeset.change(candidate_id: candidate_id)
      |> Repo.update!()
    end)

    {:ok, %{candidate_count: length(candidate_ids)}}
  end

  @doc """
  Score stage. Applies the Frame's `money_gate` to each JobPosting,
  writing or rewriting a PaidJobSignal classification per posting (in
  place — rule 8 of story 743), then recomputes each Candidate's
  aggregated score as the count of `gated_in` member signals.

  No HTTP requests, no corpus refetch.
  """
  @spec score(Ecto.UUID.t()) ::
          {:ok, %{per_candidate: list()}} | {:error, term()}
  def score(frame_id) when is_binary(frame_id) do
    case Repo.get(Frame, frame_id) do
      nil -> {:error, :not_found}
      %Frame{} = frame -> score_frame(frame)
    end
  end

  defp score_frame(%Frame{} = frame) do
    gate = normalize_money_gate(frame.money_gate)

    postings =
      Repo.all(
        from(jp in JobPosting,
          where: jp.frame_id == ^frame.id and not is_nil(jp.candidate_id)
        )
      )

    Enum.each(postings, fn posting -> upsert_signal(posting, gate) end)

    per_candidate = recompute_candidate_scores(frame.id)
    {:ok, %{per_candidate: per_candidate}}
  end

  defp normalize_money_gate(%{"total_spent_min" => t, "hire_rate_min" => h}),
    do: %{total_spent_min: t, hire_rate_min: h}

  defp normalize_money_gate(%{total_spent_min: _, hire_rate_min: _} = gate), do: gate

  defp upsert_signal(%JobPosting{} = posting, gate) do
    classification =
      if clears_gate?(posting, gate), do: :gated_in, else: :gated_out

    case Repo.get_by(PaidJobSignal, job_posting_id: posting.id) do
      nil ->
        Repo.insert!(
          PaidJobSignal.changeset(%PaidJobSignal{}, %{
            job_posting_id: posting.id,
            candidate_id: posting.candidate_id,
            classification: classification
          })
        )

      %PaidJobSignal{} = existing ->
        existing
        |> PaidJobSignal.reclassify_changeset(classification)
        |> Repo.update!()
    end
  end

  defp clears_gate?(%JobPosting{} = posting, %{total_spent_min: t_min, hire_rate_min: h_min}) do
    spent_cents = posting.total_spent_cents || 0
    rate = posting.hire_rate || 0

    spent_cents >= t_min * 100 and rate >= h_min
  end

  defp recompute_candidate_scores(frame_id) do
    candidates =
      Repo.all(
        from(c in Candidate,
          where: c.frame_id == ^frame_id,
          left_join: pjs in assoc(c, :paid_job_signals),
          on: pjs.classification == :gated_in,
          group_by: c.id,
          select: {c, count(pjs.id)}
        )
      )

    Enum.map(candidates, fn {candidate, gated_in_count} ->
      candidate
      |> Ecto.Changeset.change(score: gated_in_count)
      |> Repo.update!()

      %{candidate_id: candidate.id, score: gated_in_count}
    end)
  end

  @doc """
  Red-team stage. Writes or overwrites the RedTeamVerdict for a Candidate.
  The verdict is the agent's prosecution output (story 741); overwriting
  is the documented behavior (the founder's reframed verdict beats Score's
  mechanical classification, see `problem-discovery-skill.md`).
  """
  @spec red_team(Ecto.UUID.t(), map()) :: {:ok, RedTeamVerdict.t()} | {:error, term()}
  def red_team(candidate_id, attrs) when is_binary(candidate_id) do
    attrs = Map.put(attrs, :candidate_id, candidate_id)

    existing = Repo.get_by(RedTeamVerdict, candidate_id: candidate_id)
    base = existing || %RedTeamVerdict{}

    base
    |> RedTeamVerdict.changeset(attrs)
    |> Repo.insert_or_update()
  end
end
