defmodule MarketMySpec.ProblemDiscovery.Clustering.Scholar do
  @moduledoc """
  `Clustering` backend: `Scholar.Cluster.KMeans` with silhouette-K search.

  Determinism: a fixed `seed:` (default 42) means same input → same
  assignments + same centroids. K selection sweeps `:k_range` (default
  `3..8`) and picks the K with the highest silhouette score.

  Performance: depends on Nx backend. EXLA (configured in `config.exs`)
  gets a 50-vector × 1536-dim clustering done in seconds; the pure-Elixir
  BinaryBackend takes minutes.
  """

  @behaviour MarketMySpec.ProblemDiscovery.Clustering

  alias Scholar.Cluster.KMeans
  alias Scholar.Metrics.Clustering

  @default_k_range 3..8
  @default_seed 42

  @impl true
  def cluster([], _opts), do: {:error, :empty_input}

  def cluster(embeddings, opts) when is_list(embeddings) do
    tensor = Nx.tensor(embeddings, type: :f32)
    seed = Keyword.get(opts, :seed, @default_seed)

    case Keyword.get(opts, :k) do
      nil ->
        cluster_with_search(tensor, Keyword.get(opts, :k_range, @default_k_range), seed)

      k when is_integer(k) and k > 0 ->
        cluster_with_k(tensor, k, seed)
    end
  end

  defp cluster_with_k(tensor, k, seed) do
    n = Nx.axis_size(tensor, 0)

    if n < k do
      {:error, {:too_few_samples, n: n, k: k}}
    else
      key = Nx.Random.key(seed)
      model = KMeans.fit(tensor, num_clusters: k, key: key)
      assignments = model.labels |> Nx.to_list()
      centroids = model.clusters |> Nx.to_list()

      {:ok, %{assignments: assignments, centroids: centroids, k: k}}
    end
  end

  defp cluster_with_search(tensor, k_range, seed) do
    n = Nx.axis_size(tensor, 0)

    feasible_ks =
      k_range
      |> Enum.to_list()
      |> Enum.filter(fn k -> n >= k end)

    case feasible_ks do
      [] ->
        {:error, {:too_few_samples, n: n, k_range: k_range}}

      ks ->
        best =
          ks
          |> Enum.map(fn k -> {k, score_k(tensor, k, seed)} end)
          |> Enum.max_by(fn {_k, score} -> score end)

        {best_k, _} = best
        cluster_with_k(tensor, best_k, seed)
    end
  end

  defp score_k(tensor, k, seed) do
    key = Nx.Random.key(seed)
    model = KMeans.fit(tensor, num_clusters: k, key: key)

    Clustering.silhouette_score(tensor, model.labels, num_clusters: k)
    |> Nx.to_number()
  end
end
