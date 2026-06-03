defmodule MarketMySpec.ProblemDiscovery.Embeddings do
  @moduledoc """
  OpenAI Embeddings client.

  Single-purpose: take text (or a list of texts), return a 1536-dim
  embedding (or list of them) using OpenAI's `text-embedding-3-small`
  model. The only model call MMS owns — guards the bright-line
  "MMS may compute vectors; MMS may not generate prose, scores, or
  verdicts" (see `architecture/decisions/openai-embeddings.md`).

  Configuration: app-level `OPENAI_API_KEY` via env config (loaded
  through Dotenvy / `config/runtime.exs`).

  ### Tests
  The client is built via `openai_client/0`, which merges per-test
  Application config (`:openai_req_options`) so spex can inject a
  ReqCassette plug for record/replay. See
  `test/support/problem_discovery_helpers.ex` for the cassette
  pattern.
  """

  @base_url "https://api.openai.com/v1"
  @model "text-embedding-3-small"
  @dim 1536

  @type embedding :: [float()]

  @doc """
  Build the Req client used for OpenAI calls. Per-test ReqCassette plug
  merges in via `:openai_req_options` (matches the Engagements.HTTP
  pattern used by reddit_client/0).
  """
  @spec openai_client(String.t() | nil) :: Req.Request.t()
  def openai_client(api_key \\ default_api_key()) do
    base =
      Req.new(
        headers: openai_headers(api_key),
        receive_timeout: 30_000
      )

    Req.merge(base, Application.get_env(:market_my_spec, :openai_req_options, []))
  end

  defp openai_headers(nil), do: []
  defp openai_headers(""), do: []
  defp openai_headers(api_key), do: [{"authorization", "Bearer #{api_key}"}]

  @doc """
  Embed a single piece of text. Returns `{:ok, vector}` or `{:error, reason}`.
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, opts \\ []) when is_binary(text) do
    with {:ok, [vector]} <- embed_batch([text], opts) do
      {:ok, vector}
    end
  end

  @doc """
  Embed a batch of texts in a single request. Returns
  `{:ok, [vector, ...]}` in input order or `{:error, reason}`.

  The OpenAI Embeddings API accepts arrays directly — batching is one
  request, not N — so callers should prefer this when embedding a corpus
  (e.g., a Frame's gathered postings).
  """
  @spec embed_batch([String.t()], keyword()) :: {:ok, [embedding()]} | {:error, term()}
  def embed_batch(texts, opts \\ []) when is_list(texts) do
    api_key = Keyword.get(opts, :api_key, default_api_key())
    model = Keyword.get(opts, :model, @model)

    with {:ok, api_key} <- require_api_key(api_key),
         client = openai_client(api_key),
         {:ok, %Req.Response{status: 200, body: body}} <-
           Req.post(client,
             url: "#{@base_url}/embeddings",
             json: %{model: model, input: texts}
           ),
         {:ok, vectors} <- extract_vectors(body) do
      {:ok, vectors}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  The dimensionality of the embeddings this module produces.
  Used downstream by Clustering / pgvector for sanity checks.
  """
  @spec dim() :: pos_integer()
  def dim, do: @dim

  defp extract_vectors(%{"data" => entries}) when is_list(entries) do
    vectors =
      entries
      |> Enum.sort_by(& &1["index"])
      |> Enum.map(& &1["embedding"])

    {:ok, vectors}
  end

  defp extract_vectors(body), do: {:error, {:invalid_response_shape, body}}

  defp require_api_key(nil), do: {:error, :missing_openai_api_key}
  defp require_api_key(""), do: {:error, :missing_openai_api_key}
  defp require_api_key(key), do: {:ok, key}

  defp default_api_key do
    Application.get_env(:market_my_spec, __MODULE__, [])
    |> Keyword.get(:api_key) ||
      System.get_env("OPENAI_API_KEY")
  end
end
