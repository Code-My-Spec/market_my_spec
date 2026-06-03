defmodule MarketMySpec.ProblemDiscovery.Source.Upwork do
  @moduledoc """
  Upwork `Source` implementation via Apify.

  Upwork has no public REST API with static-token auth, so we drive
  scraping through Apify's actor platform — the same approach used in
  the broken_oaths pipeline that seeded this feature. Configurable
  actor id (default `upwork-vibe~upwork-job-scraper`) lets the operator
  swap to a different scraper without code changes.

  Auth: `APIFY_API_TOKEN` env var, loaded via Dotenvy and read here via
  Application config (`MarketMySpec.ProblemDiscovery.Source.Upwork[:api_key]`).
  See `architecture/decisions/problem-discovery-data-sources.md`.

  Returns JobPosting attribute maps shaped to the JobPosting schema's
  input contract — Pipeline.Gather attaches `frame_id`,
  `saved_search_index`, `gathered_at`, and `embedding` per row.
  """

  @behaviour MarketMySpec.ProblemDiscovery.Source

  @default_actor "upwork-vibe~upwork-job-scraper"
  @default_page_size 50
  @api_base "https://api.apify.com/v2"

  @impl MarketMySpec.ProblemDiscovery.Source
  def search(%{query: query}, opts) when is_binary(query) do
    api_key = Keyword.get(opts, :api_key, default_api_key())
    actor = Keyword.get(opts, :actor, default_actor())
    limit = Keyword.get(opts, :limit, @default_page_size)

    with {:ok, api_key} <- require_api_key(api_key),
         {:ok, %Req.Response{status: status, body: body}} <-
           run_actor(api_key, actor, query, limit, opts),
         {:ok, items} <- ensure_dataset_items(status, body) do
      {:ok, Enum.map(items, &normalize/1)}
    end
  end

  @doc """
  Build the Req client used for Apify calls. Per-test ReqCassette plug
  merges via `:apify_req_options` so spex can wrap calls in
  `with_apify_cassette/2`.
  """
  @spec apify_client(String.t() | nil) :: Req.Request.t()
  def apify_client(api_key \\ default_api_key()) do
    base =
      Req.new(
        headers: apify_headers(api_key),
        receive_timeout: 120_000
      )

    Req.merge(base, Application.get_env(:market_my_spec, :apify_req_options, []))
  end

  defp apify_headers(nil), do: []
  defp apify_headers(""), do: []
  defp apify_headers(api_key), do: [{"authorization", "Bearer #{api_key}"}]

  defp run_actor(api_key, actor, query, limit, _opts) do
    Req.post(apify_client(api_key),
      url: "#{@api_base}/acts/#{actor}/run-sync-get-dataset-items",
      json: actor_input(query, limit)
    )
  end

  # Input shape matches the upwork-vibe~upwork-job-scraper actor — see
  # broken_oaths/discovery/sweep.py for the validated production input.
  #
  # The actor's `keywords` field is a list it OR-matches over individual
  # tokens. Passing the whole query as `[query]` makes Upwork search for
  # an exact phrase appearance, which matches almost nothing for the
  # multi-word concept queries the skill recommends (e.g. "GoHighLevel
  # agency sub-account migration"). Split on whitespace so the actor
  # gets one keyword per token.
  defp actor_input(query, limit) do
    keywords =
      query
      |> String.split(~r/\s+/, trim: true)
      |> Enum.uniq()

    %{
      "limit" => limit,
      "includeKeywords.keywords" => keywords,
      "includeKeywords.matchTitle" => true,
      "includeKeywords.matchDescription" => true,
      "includeKeywords.matchSkills" => false
    }
  end

  defp ensure_dataset_items(200, items) when is_list(items), do: {:ok, items}
  defp ensure_dataset_items(201, items) when is_list(items), do: {:ok, items}

  defp ensure_dataset_items(status, body),
    do: {:error, {:http_error, status, body}}

  defp normalize(item) do
    %{
      source: "upwork",
      source_id: extract_source_id(item),
      title: item["title"] || "",
      description: extract_description(item),
      url: extract_url(item),
      total_spent_cents: extract_total_spent_cents(item),
      hire_rate: extract_hire_rate(item)
    }
  end

  defp extract_source_id(item) do
    item["uid"] || item["ciphertext"] || item["id"] || item["url"] ||
      inspect(:erlang.unique_integer([:positive]))
  end

  defp extract_description(item), do: item["description"] || item["snippet"] || ""

  defp extract_url(item), do: item["externalLink"] || item["url"] || item["link"]

  defp extract_total_spent_cents(item) do
    raw =
      get_in(item, ["client", "stats", "totalSpent"]) ||
        item["clientTotalSpent"] ||
        get_in(item, ["client", "totalSpent"]) ||
        get_in(item, ["client", "total_spent"]) ||
        item["totalSpent"]

    case raw do
      n when is_number(n) -> round(n * 100)
      _ -> nil
    end
  end

  defp extract_hire_rate(item) do
    raw =
      get_in(item, ["client", "stats", "hireRate"]) ||
        item["clientHireRate"] ||
        get_in(item, ["client", "hireRate"]) ||
        get_in(item, ["client", "hire_rate"]) ||
        item["hireRate"]

    case raw do
      n when is_number(n) and n <= 1.0 -> round(n * 100)
      n when is_number(n) -> round(n)
      _ -> nil
    end
  end

  defp require_api_key(nil), do: {:error, :missing_upwork_api_key}
  defp require_api_key(""), do: {:error, :missing_upwork_api_key}
  defp require_api_key(key), do: {:ok, key}

  defp default_api_key do
    Application.get_env(:market_my_spec, __MODULE__, [])
    |> Keyword.get(:api_key)
  end

  defp default_actor do
    Application.get_env(:market_my_spec, __MODULE__, [])
    |> Keyword.get(:actor, @default_actor)
  end
end
