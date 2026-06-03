defmodule MarketMySpec.ProblemDiscovery.Clustering.Recorder do
  @moduledoc """
  Test-only `Clustering` backend that caches Scholar.KMeans outputs to disk
  keyed by an input fingerprint, so spex tests replay results in
  microseconds instead of re-running KMeans (seconds-per-call even on EXLA).

  Cassette format: one JSON file per fingerprint under
  `test/cassettes/clustering/<fingerprint>.json`. The fingerprint is a
  SHA-256 over the rounded embeddings + opts, so identical inputs always
  hit the same cassette.

  Modes (via `REQ_CASSETTE_MODE` env var to stay symmetric with
  ReqCassette's record/replay/bypass — same env, same semantics):
  - `replay` (default): cache miss → error. Forces all clustering to be
    pre-recorded; flags accidental clustering drift.
  - `record`: cache miss → call Scholar + write. Cache hit → replay.
  - `bypass`: always call Scholar; never read or write the cache.
  """

  @behaviour MarketMySpec.ProblemDiscovery.Clustering

  alias MarketMySpec.ProblemDiscovery.Clustering.Scholar

  @cassette_dir "test/cassettes/clustering"

  @impl true
  def cluster([], opts), do: Scholar.cluster([], opts)

  def cluster(embeddings, opts) when is_list(embeddings) do
    case mode() do
      :bypass -> Scholar.cluster(embeddings, opts)
      :record -> record_or_replay(embeddings, opts)
      :replay -> replay_only(embeddings, opts)
    end
  end

  defp record_or_replay(embeddings, opts) do
    path = cassette_path(embeddings, opts)

    case load(path) do
      {:ok, cached} -> {:ok, cached}
      :miss ->
        with {:ok, result} <- Scholar.cluster(embeddings, opts) do
          save!(path, result)
          {:ok, result}
        end
    end
  end

  defp replay_only(embeddings, opts) do
    path = cassette_path(embeddings, opts)

    case load(path) do
      {:ok, cached} -> {:ok, cached}
      :miss -> {:error, {:clustering_cassette_miss, path: path}}
    end
  end

  defp cassette_path(embeddings, opts) do
    Path.join(@cassette_dir, fingerprint(embeddings, opts) <> ".json")
  end

  # Quantize floats to 6 decimal places before hashing so EXLA's
  # 7th-decimal jitter across re-runs doesn't blow the cache.
  defp fingerprint(embeddings, opts) do
    payload = %{
      embeddings: Enum.map(embeddings, &Enum.map(&1, fn f -> Float.round(f, 6) end)),
      opts: opts |> Keyword.take([:k, :k_range, :seed]) |> Enum.into(%{}) |> inspect()
    }

    :crypto.hash(:sha256, :erlang.term_to_binary(payload)) |> Base.encode16(case: :lower)
  end

  defp load(path) do
    if File.exists?(path) do
      with {:ok, body} <- File.read(path),
           {:ok, %{"assignments" => a, "centroids" => c, "k" => k}} <- Jason.decode(body) do
        {:ok, %{assignments: a, centroids: c, k: k}}
      else
        _ -> :miss
      end
    else
      :miss
    end
  end

  defp save!(path, result) do
    File.mkdir_p!(@cassette_dir)
    File.write!(path, Jason.encode!(result, pretty: false))
  end

  defp mode do
    case System.get_env("REQ_CASSETTE_MODE") do
      "record" -> :record
      "bypass" -> :bypass
      _ -> :replay
    end
  end
end
