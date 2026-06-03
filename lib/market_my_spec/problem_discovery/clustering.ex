defmodule MarketMySpec.ProblemDiscovery.Clustering do
  @moduledoc """
  Behaviour + dispatch for the Cluster stage. Takes a list of pgvector-shaped
  embeddings and produces a partition: K cluster assignments + K centroids.

  Backends:
  - `Clustering.Scholar` — real `Scholar.Cluster.KMeans` with silhouette-K
    search (used in :dev/:prod).
  - `Clustering.Recorder` — wraps Scholar in test; records outputs to
    `test/cassettes/clustering/` keyed by an input fingerprint so subsequent
    test runs replay from disk instead of re-running KMeans (which is
    seconds-per-call even on EXLA).

  The active backend is selected via
  `Application.get_env(:market_my_spec, MarketMySpec.ProblemDiscovery.Clustering)`;
  default is `Clustering.Scholar`.
  """

  @type embedding :: [float()]
  @type cluster_id :: non_neg_integer()

  @type result :: %{
          assignments: [cluster_id()],
          centroids: [embedding()],
          k: pos_integer()
        }

  @callback cluster([embedding()], keyword()) :: {:ok, result()} | {:error, term()}

  @doc """
  Cluster the given embeddings into K groups, dispatching to the
  configured implementation.

  Opts:
  - `:k` — pin K explicitly; skips silhouette search.
  - `:k_range` — Range to sweep when `:k` is not pinned (default `3..8`).
  - `:seed` — RNG seed for determinism (default `42`).
  """
  @spec cluster([embedding()], keyword()) :: {:ok, result()} | {:error, term()}
  def cluster(embeddings, opts \\ []) do
    impl().cluster(embeddings, opts)
  end

  defp impl do
    Application.get_env(:market_my_spec, __MODULE__, MarketMySpec.ProblemDiscovery.Clustering.Scholar)
  end
end
