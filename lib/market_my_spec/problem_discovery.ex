defmodule MarketMySpec.ProblemDiscovery do
  @moduledoc """
  Public API for the ProblemDiscovery context.

  Takes a founder's fuzzy hypothesis through the 5-stage pipeline
  (Gather → Cluster → Score → Red-team → Board) over money-validated
  job postings. Surface for the LiveView (`ProblemDiscoveryLive`) and
  the MCP tools (`MarketMySpec.McpServers.ProblemDiscovery.Tools.*`).

  Stage-level operations delegate to `Pipeline`. Artifact CRUD goes
  through Repo directly here for read paths and through changesets for
  mutations. Board assembly is `Board.assemble/1`.

  See `architecture/decisions/problem-discovery-clustering.md` for the
  architecture and `architecture/decisions/problem-discovery-skill.md`
  for the agent's skill-guided flow over this surface.
  """

  import Ecto.Query

  alias MarketMySpec.ProblemDiscovery.Board
  alias MarketMySpec.ProblemDiscovery.Candidate
  alias MarketMySpec.ProblemDiscovery.Frame
  alias MarketMySpec.ProblemDiscovery.JobPosting
  alias MarketMySpec.ProblemDiscovery.PaidJobSignal
  alias MarketMySpec.ProblemDiscovery.Pipeline
  alias MarketMySpec.ProblemDiscovery.RedTeamVerdict
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope

  # --- Frames -------------------------------------------------------------

  @doc "List Frames in the active account scope."
  @spec list_frames(Scope.t()) :: [Frame.t()]
  def list_frames(%Scope{active_account_id: account_id}) do
    Repo.all(
      from(f in Frame,
        where: f.account_id == ^account_id,
        order_by: [desc: f.updated_at]
      )
    )
  end

  @doc "Fetch a Frame by id, scoped to the active account."
  @spec get_frame(Scope.t(), Ecto.UUID.t()) :: {:ok, Frame.t()} | {:error, :not_found}
  def get_frame(%Scope{active_account_id: account_id}, frame_id) do
    case Repo.get_by(Frame, id: frame_id, account_id: account_id) do
      nil -> {:error, :not_found}
      %Frame{} = frame -> {:ok, frame}
    end
  end

  @doc "Create a Frame in the active account scope."
  @spec create_frame(Scope.t(), map()) :: {:ok, Frame.t()} | {:error, Ecto.Changeset.t()}
  def create_frame(%Scope{active_account_id: account_id}, attrs) do
    attrs = Map.put(attrs, :account_id, account_id)

    %Frame{}
    |> Frame.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Update a Frame in the active account scope."
  @spec update_frame(Scope.t(), Ecto.UUID.t(), map()) ::
          {:ok, Frame.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_frame(%Scope{} = scope, frame_id, attrs) do
    with {:ok, frame} <- get_frame(scope, frame_id) do
      attrs = preserve_gathered_at(frame, attrs)

      frame
      |> Frame.changeset(attrs)
      |> Repo.update()
    end
  end

  # When an agent re-submits saved_searches via UpdateFrame, the incoming
  # entries carry only :source/:query. Carry forward the gathered_at
  # marker from the matching existing entry so already-gathered searches
  # stay skipped on the next RunGather.
  defp preserve_gathered_at(%Frame{saved_searches: existing}, %{saved_searches: incoming} = attrs)
       when is_list(existing) and is_list(incoming) do
    by_key = Map.new(existing, fn entry -> {saved_search_key(entry), get_gathered_at(entry)} end)

    merged =
      Enum.map(incoming, fn entry ->
        case Map.get(by_key, saved_search_key(entry)) do
          ts when is_binary(ts) -> Map.put(entry, :gathered_at, ts)
          _ -> entry
        end
      end)

    %{attrs | saved_searches: merged}
  end

  defp preserve_gathered_at(_frame, attrs), do: attrs

  defp saved_search_key(%{source: s, query: q}), do: {s, q}
  defp saved_search_key(%{"source" => s, "query" => q}), do: {s, q}
  defp saved_search_key(_), do: nil

  defp get_gathered_at(%{gathered_at: ts}) when is_binary(ts), do: ts
  defp get_gathered_at(%{"gathered_at" => ts}) when is_binary(ts), do: ts
  defp get_gathered_at(_), do: nil

  # --- Pipeline stages ----------------------------------------------------

  @doc "Run Gather for a Frame; per-saved-search additive."
  @spec run_gather(Scope.t(), Ecto.UUID.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def run_gather(%Scope{} = scope, frame_id, opts \\ []) do
    with {:ok, _frame} <- get_frame(scope, frame_id) do
      Pipeline.gather(frame_id, opts)
    end
  end

  @doc """
  Probe-mode Gather against an uncommitted draft Frame. Returns a sample
  without persisting (criterion 6580). Used during Frame composition.
  """
  @spec probe_gather(Scope.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def probe_gather(%Scope{}, draft_frame, opts \\ []) when is_map(draft_frame) do
    Pipeline.probe(draft_frame, opts)
  end

  @doc "Run Cluster for a Frame; one KMeans pass + Candidate persistence."
  @spec run_cluster(Scope.t(), Ecto.UUID.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def run_cluster(%Scope{} = scope, frame_id, opts \\ []) do
    with {:ok, _frame} <- get_frame(scope, frame_id) do
      Pipeline.cluster(frame_id, opts)
    end
  end

  @doc "Run Score for a Frame; in-place PaidJobSignal classification."
  @spec run_score(Scope.t(), Ecto.UUID.t()) :: {:ok, map()} | {:error, term()}
  def run_score(%Scope{} = scope, frame_id) do
    with {:ok, _frame} <- get_frame(scope, frame_id) do
      Pipeline.score(frame_id)
    end
  end

  # --- Candidates ---------------------------------------------------------

  @doc "List Candidates for a Frame with associated counts."
  @spec list_candidates(Scope.t(), Ecto.UUID.t()) :: {:ok, [Candidate.t()]} | {:error, :not_found}
  def list_candidates(%Scope{} = scope, frame_id) do
    with {:ok, _frame} <- get_frame(scope, frame_id) do
      candidates =
        Repo.all(
          from(c in Candidate,
            where: c.frame_id == ^frame_id,
            order_by: [desc: c.score]
          )
        )
        |> Repo.preload([:red_team_verdict, :paid_job_signals, :job_postings])

      {:ok, candidates}
    end
  end

  @doc "Assign or overwrite a Candidate's semantic label (LabelCandidate)."
  @spec label_candidate(Scope.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, Candidate.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def label_candidate(%Scope{} = scope, candidate_id, label) when is_binary(label) do
    with {:ok, candidate} <- get_candidate(scope, candidate_id) do
      candidate
      |> Ecto.Changeset.change(label: label)
      |> Repo.update()
    end
  end

  @doc """
  Merge Candidates into a single target. Recomputes centroid as mean of
  combined members, reassigns child JobPostings and PaidJobSignals,
  preserves the target's RedTeamVerdict, drops the merged-from
  Candidates and their verdicts.
  """
  @spec merge_candidates(Scope.t(), [Ecto.UUID.t()], Ecto.UUID.t()) ::
          {:ok, Candidate.t()} | {:error, term()}
  def merge_candidates(%Scope{} = scope, candidate_ids, target_id)
      when is_list(candidate_ids) do
    with {:ok, target} <- get_candidate(scope, target_id),
         all when length(all) == length(candidate_ids) <-
           Repo.all(from(c in Candidate, where: c.id in ^candidate_ids)) do
      from(jp in JobPosting, where: jp.candidate_id in ^candidate_ids)
      |> Repo.update_all(set: [candidate_id: target.id])

      from(pjs in PaidJobSignal, where: pjs.candidate_id in ^candidate_ids)
      |> Repo.update_all(set: [candidate_id: target.id])

      Repo.delete_all(
        from(c in Candidate,
          where: c.id in ^candidate_ids and c.id != ^target.id
        )
      )

      recompute_centroid(target)
    end
  end

  @doc """
  Split a Candidate into multiple by partitioning its member JobPostings.
  `partition` is a list of lists of JobPosting ids; each inner list becomes
  a new Candidate. The original Candidate (and its RedTeamVerdict, since
  the partition shape changed) is deleted.
  """
  @spec split_candidate(Scope.t(), Ecto.UUID.t(), [[Ecto.UUID.t()]]) ::
          {:ok, [Candidate.t()]} | {:error, term()}
  def split_candidate(%Scope{} = scope, candidate_id, partition)
      when is_list(partition) do
    with {:ok, candidate} <- get_candidate(scope, candidate_id) do
      new_candidates =
        Enum.map(partition, fn job_posting_ids ->
          {:ok, new_cand} =
            %Candidate{}
            |> Candidate.changeset(%{
              frame_id: candidate.frame_id,
              centroid: candidate.centroid
            })
            |> Repo.insert()

          from(jp in JobPosting, where: jp.id in ^job_posting_ids)
          |> Repo.update_all(set: [candidate_id: new_cand.id])

          from(pjs in PaidJobSignal, where: pjs.job_posting_id in ^job_posting_ids)
          |> Repo.update_all(set: [candidate_id: new_cand.id])

          recompute_centroid(new_cand)
        end)

      Repo.delete(candidate)

      {:ok, Enum.map(new_candidates, fn {:ok, c} -> c end)}
    end
  end

  defp recompute_centroid(%Candidate{} = candidate) do
    postings =
      Repo.all(
        from(jp in JobPosting,
          where: jp.candidate_id == ^candidate.id,
          select: jp.embedding
        )
      )

    update_centroid_from(candidate, postings)
  end

  defp update_centroid_from(candidate, []), do: {:ok, candidate}

  defp update_centroid_from(candidate, vectors) do
    centroid = mean_vector(vectors)

    candidate
    |> Ecto.Changeset.change(centroid: Pgvector.new(centroid))
    |> Repo.update()
  end

  defp mean_vector(vectors) do
    lists = Enum.map(vectors, &Pgvector.to_list/1)
    dim = length(hd(lists))
    n = length(lists)

    for i <- 0..(dim - 1) do
      Enum.reduce(lists, 0.0, fn list, acc -> acc + Enum.at(list, i) end) / n
    end
  end

  defp get_candidate(%Scope{active_account_id: account_id}, candidate_id) do
    candidate =
      Repo.one(
        from(c in Candidate,
          join: f in assoc(c, :frame),
          where: c.id == ^candidate_id and f.account_id == ^account_id
        )
      )

    case candidate do
      nil -> {:error, :not_found}
      %Candidate{} = c -> {:ok, c}
    end
  end

  # --- JobPostings --------------------------------------------------------

  @doc "Write a pain_descriptor on a JobPosting (SetPainDescriptor tool — pass 1 of 3-pass refinement)."
  @spec set_pain_descriptor(Scope.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, JobPosting.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def set_pain_descriptor(%Scope{active_account_id: account_id}, job_posting_id, descriptor) do
    posting =
      Repo.one(
        from(jp in JobPosting,
          join: f in assoc(jp, :frame),
          where: jp.id == ^job_posting_id and f.account_id == ^account_id
        )
      )

    case posting do
      nil ->
        {:error, :not_found}

      %JobPosting{} = jp ->
        jp
        |> JobPosting.describe_pain_changeset(descriptor)
        |> Repo.update()
    end
  end

  # --- Red-team -----------------------------------------------------------

  @doc "Prosecute a Candidate (RedTeamCandidate tool); writes or overwrites the verdict."
  @spec red_team_candidate(Scope.t(), Ecto.UUID.t(), map()) ::
          {:ok, RedTeamVerdict.t()} | {:error, term()}
  def red_team_candidate(%Scope{} = scope, candidate_id, attrs) do
    with {:ok, _candidate} <- get_candidate(scope, candidate_id) do
      Pipeline.red_team(candidate_id, attrs)
    end
  end

  # --- Board --------------------------------------------------------------

  @doc "Assemble the killable-in-one-click Board view for a Frame."
  @spec get_board(Scope.t(), Ecto.UUID.t()) ::
          {:ok, Board.View.t()} | {:error, :not_found}
  def get_board(%Scope{} = scope, frame_id) do
    with {:ok, _frame} <- get_frame(scope, frame_id) do
      Board.assemble(frame_id)
    end
  end
end
