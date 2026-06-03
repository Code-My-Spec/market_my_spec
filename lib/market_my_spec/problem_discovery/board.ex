defmodule MarketMySpec.ProblemDiscovery.Board do
  @moduledoc """
  Projection module that assembles a Board view for a Frame.

  Read-only; no schema. Composes the persisted typed artifacts (Frame,
  Candidate, PaidJobSignal, RedTeamVerdict) into the killable-in-one-click
  view the founder consumes through the LiveView (story 739) and the
  agent reads via the `GetBoard` MCP tool.

  Per criterion 6527, Candidates whose member JobPostings carry no
  openable URLs are dropped pre-Board — the founder needs at least one
  link to verify the evidence with their own eyes.

  Per criterion 6534, the candidates returned here are typed
  `%Candidate{}` structs with associations preloaded, not raw maps.
  """

  import Ecto.Query

  alias MarketMySpec.ProblemDiscovery.Candidate
  alias MarketMySpec.ProblemDiscovery.Frame
  alias MarketMySpec.ProblemDiscovery.JobPosting
  alias MarketMySpec.Repo

  defmodule View do
    @moduledoc """
    Typed Board projection returned by `Board.assemble/1`. Distinct from
    raw maps so the LiveView can pattern-match on `%View{}` and consumers
    can rely on typed fields rather than parsing dynamic shapes.
    """

    @type corpus_health :: %{
            total_postings: non_neg_integer(),
            postings_gated_in: non_neg_integer(),
            distinct_clients_in_keep_tier: non_neg_integer()
          }

    @type t :: %__MODULE__{
            frame: MarketMySpec.ProblemDiscovery.Frame.t(),
            candidates: [MarketMySpec.ProblemDiscovery.Candidate.t()],
            awaiting_redteam: non_neg_integer(),
            corpus_health: corpus_health(),
            kill_condition_status: :met | :not_met
          }

    defstruct [:frame, :candidates, :awaiting_redteam, :corpus_health, :kill_condition_status]
  end

  @doc """
  Assemble the Board projection for the given Frame id.

  Returns `{:ok, %View{}}` or `{:error, :not_found}`.
  """
  @spec assemble(Ecto.UUID.t()) :: {:ok, View.t()} | {:error, :not_found}
  def assemble(frame_id) when is_binary(frame_id) do
    case Repo.get(Frame, frame_id) do
      nil -> {:error, :not_found}
      %Frame{} = frame -> {:ok, build_view(frame)}
    end
  end

  defp build_view(%Frame{} = frame) do
    # Score-survivors only (score > 0) — sub-score Candidates can't be
    # red-teamed and don't belong on the Board. Then split survivors into
    # rendered (have a RedTeamVerdict) vs awaiting (don't), filtering both
    # buckets by openable evidence per criterion 6527.
    survivors =
      frame.id
      |> candidates_query()
      |> Repo.all()
      |> Repo.preload([:red_team_verdict, :job_postings, paid_job_signals: :job_posting])
      |> Enum.filter(&(score_survivor?(&1) and has_openable_evidence?(&1)))

    {with_verdict, awaiting} = Enum.split_with(survivors, &has_verdict?/1)

    %View{
      frame: frame,
      candidates: with_verdict,
      awaiting_redteam: length(awaiting),
      corpus_health: corpus_health(frame.id),
      kill_condition_status: kill_condition_status(frame, with_verdict)
    }
  end

  defp score_survivor?(%Candidate{score: score}) when is_integer(score) and score > 0, do: true
  defp score_survivor?(_), do: false

  defp has_verdict?(%Candidate{red_team_verdict: %{verdict: v}}) when not is_nil(v), do: true
  defp has_verdict?(_), do: false

  defp candidates_query(frame_id) do
    from(c in Candidate, where: c.frame_id == ^frame_id, order_by: [desc: c.score])
  end

  defp has_openable_evidence?(%Candidate{job_postings: postings}) when is_list(postings) do
    Enum.any?(postings, fn %JobPosting{url: url} ->
      is_binary(url) and (String.starts_with?(url, "http://") or String.starts_with?(url, "https://"))
    end)
  end

  defp has_openable_evidence?(_), do: false

  defp corpus_health(frame_id) do
    total =
      Repo.aggregate(
        from(jp in JobPosting, where: jp.frame_id == ^frame_id),
        :count
      )

    gated_in =
      Repo.aggregate(
        from(jp in JobPosting,
          join: pjs in assoc(jp, :paid_job_signal),
          where: jp.frame_id == ^frame_id and pjs.classification == :gated_in
        ),
        :count
      )

    distinct_clients =
      Repo.aggregate(
        from(jp in JobPosting,
          join: pjs in assoc(jp, :paid_job_signal),
          where: jp.frame_id == ^frame_id and pjs.classification == :gated_in,
          distinct: jp.source_id,
          select: jp.source_id
        ),
        :count
      )

    %{
      total_postings: total,
      postings_gated_in: gated_in,
      distinct_clients_in_keep_tier: distinct_clients
    }
  end

  defp kill_condition_status(%Frame{kill_condition: kill_condition}, candidates) do
    threshold = kill_condition_threshold(kill_condition)
    money_gated_count = Enum.count(candidates, &money_gated?/1)

    if money_gated_count >= threshold, do: :met, else: :not_met
  end

  defp kill_condition_threshold(%{"min_money_gated_candidates" => n}), do: n
  defp kill_condition_threshold(%{min_money_gated_candidates: n}), do: n
  defp kill_condition_threshold(_), do: 0

  defp money_gated?(%Candidate{score: score}) when is_integer(score) and score > 0, do: true
  defp money_gated?(_), do: false
end
