defmodule MarketMySpec.Engagements.Source.Reddit do
  @moduledoc """
  Reddit Source adapter.

  v1 uses anonymous read against `https://www.reddit.com/r/<sub>/search.json`
  with a descriptive User-Agent — no OAuth, no bearer (see knowledge/reddit-api.md
  for the OAuth path, deferred to story 707 when the agent needs `submit`).

  ## search/3

  Issues `GET /r/{sub}/search.json?q=<q>&restrict_sr=1&sort=new&limit=25`
  (plus `&after=<cursor>` when paginating). Maps Reddit's Listing JSON to
  the canonical candidate shape (`title, source, url, score, reply_count,
  recency, snippet`). `recency` is `created_utc` for v1 (last-activity
  requires a per-thread API call — see story 706 follow-up).

  ## get_thread/2, post/3

  Still scaffolds — implemented in stories 706 and 707.
  """

  @behaviour MarketMySpec.Engagements.Source

  alias MarketMySpec.Engagements.HTTP

  @snippet_length 280

  @doc """
  Validates subreddit name format.
  Subreddit names must be 3-21 characters, containing only letters, numbers,
  and underscores.
  """
  @spec validate_venue(String.t()) :: :ok | {:error, String.t()}
  def validate_venue(identifier) when is_binary(identifier) do
    if Regex.match?(~r/^[a-zA-Z0-9_]{3,21}$/, identifier) do
      :ok
    else
      {:error,
       "Invalid subreddit name '#{identifier}': must be 3-21 characters, letters, numbers, underscores only"}
    end
  end

  def validate_venue(_identifier), do: {:error, "Subreddit name must be a string"}

  @doc """
  Searches a subreddit via Reddit's per-subreddit search.json endpoint.

  Returns `{:ok, %{candidates: [candidate], next_cursor: nil | string}}` on
  HTTP 200, or `{:error, reason}` on non-200 / network failure. The
  orchestrator collects the per-venue failure into the response envelope's
  `failures` list.

  Accepts an optional `:cursor` opt for pagination — passed as Reddit's
  `after` query param.
  """
  @spec search(map(), String.t(), keyword()) ::
          {:ok, %{candidates: [map()], next_cursor: nil | String.t()}} | {:error, term()}
  def search(venue, query, opts \\ []) when is_binary(query) do
    cursor = Keyword.get(opts, :cursor)
    params = [q: query, restrict_sr: 1, sort: "new", limit: 25]
    params = if is_binary(cursor) and cursor != "", do: params ++ [after: cursor], else: params

    case Req.get(HTTP.reddit_client(),
           url: "/r/#{venue.identifier}/search.json",
           params: params
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        candidates =
          body
          |> get_in(["data", "children"])
          |> List.wrap()
          |> Enum.map(&normalize_child/1)
          |> Enum.reject(&is_nil/1)

        next_cursor = get_in(body, ["data", "after"])
        {:ok, %{candidates: candidates, next_cursor: next_cursor}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_child(%{"data" => data}) when is_map(data) do
    source_thread_id = Map.get(data, "id")

    if is_nil(source_thread_id) or source_thread_id == "" do
      nil
    else
      %{
        "source_thread_id" => source_thread_id,
        "title" => Map.get(data, "title", ""),
        "source" => "reddit",
        "url" => "https://www.reddit.com" <> (Map.get(data, "permalink") || ""),
        "score" => Map.get(data, "score") || Map.get(data, "ups") || 0,
        "reply_count" => Map.get(data, "num_comments", 0),
        "recency" => Map.get(data, "created_utc"),
        "snippet" => (Map.get(data, "selftext") || "") |> snippet()
      }
    end
  end

  defp normalize_child(_other), do: nil

  defp snippet(text) when is_binary(text), do: String.slice(text, 0, @snippet_length)
  defp snippet(_), do: ""

  @doc """
  Fetches full Reddit thread JSON via `GET /comments/<id>.json` and
  normalizes it into a Thread-compatible map with a comment_tree preserving
  Reddit's response order at every level. Each comment carries author, body,
  score, created_utc, and depth.

  Returns `{:ok, map}` on HTTP 200, `{:error, reason}` on non-200 or
  network failure. The caller (ThreadsRepository or GetThread tool) decides
  whether to write the result to the DB.

  Default page caps top-level comments at 25; passes `limit=25` to Reddit.
  Comments cursor (Reddit's `data.after`) is included in the returned map
  so the tool layer can surface it.
  """
  @spec get_thread(map() | nil, String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_thread(_venue, source_thread_id, opts \\ []) do
    sort = Keyword.get(opts, :sort, "confidence")
    limit = Keyword.get(opts, :limit, 25)
    after_param = Keyword.get(opts, :after, nil)

    params = [sort: sort, limit: limit]
    params = if is_binary(after_param) and after_param != "", do: params ++ [after: after_param], else: params

    case Req.get(HTTP.reddit_client(),
           url: "/comments/#{source_thread_id}.json",
           params: params
         ) do
      {:ok, %Req.Response{status: 200, body: [post_listing, comments_listing]}} ->
        normalize_thread_response(source_thread_id, post_listing, comments_listing)

      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) and length(body) >= 2 ->
        [post_listing | [comments_listing | _]] = body
        normalize_thread_response(source_thread_id, post_listing, comments_listing)

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_thread_response(source_thread_id, post_listing, comments_listing) do
    post_data =
      post_listing
      |> get_in(["data", "children"])
      |> List.wrap()
      |> List.first()
      |> case do
        %{"data" => d} -> d
        _ -> %{}
      end

    op_body = Map.get(post_data, "selftext", "")
    title = Map.get(post_data, "title", "Thread #{source_thread_id}")
    post_created_utc = Map.get(post_data, "created_utc")

    raw_comments =
      comments_listing
      |> get_in(["data", "children"])
      |> List.wrap()

    comments_cursor = get_in(comments_listing, ["data", "after"])

    {comment_tree, normalization_error} =
      try do
        tree =
          raw_comments
          |> Enum.map(&normalize_comment(&1, 0))
          |> Enum.reject(&is_nil/1)

        {tree, nil}
      rescue
        e -> {nil, Exception.message(e)}
      end

    last_activity_at =
      if comment_tree && comment_tree != [] do
        max_utc =
          comment_tree
          |> flatten_comments()
          |> Enum.map(&Map.get(&1, "created_utc"))
          |> Enum.reject(&is_nil/1)
          |> Enum.max(fn -> nil end)

        utc_to_datetime(max_utc) || utc_to_datetime(post_created_utc)
      else
        utc_to_datetime(post_created_utc)
      end

    result = %{
      title: title,
      op_body: op_body,
      comment_tree: %{"children" => comment_tree || []},
      raw_payload: %{
        "post" => post_listing,
        "comments" => comments_listing
      },
      last_activity_at: last_activity_at,
      comments_cursor: comments_cursor
    }

    result =
      if normalization_error do
        Map.put(result, :normalization_error, normalization_error)
      else
        result
      end

    {:ok, result}
  end

  defp normalize_comment(%{"kind" => "t1", "data" => data}, depth) do
    replies_raw =
      case Map.get(data, "replies") do
        %{"data" => %{"children" => children}} -> children
        _ -> []
      end

    replies =
      replies_raw
      |> Enum.map(&normalize_comment(&1, depth + 1))
      |> Enum.reject(&is_nil/1)

    comment = %{
      "id" => Map.fetch!(data, "id"),
      "author" => Map.fetch!(data, "author"),
      "body" => Map.fetch!(data, "body"),
      "score" => Map.get(data, "score", 0),
      "created_utc" => Map.get(data, "created_utc"),
      "depth" => depth
    }

    if replies == [] do
      comment
    else
      Map.put(comment, "replies", %{"children" => replies})
    end
  end

  defp normalize_comment(_other, _depth), do: nil

  defp flatten_comments(comments) when is_list(comments) do
    comments
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(fn c ->
      nested =
        case Map.get(c, "replies") do
          %{"children" => children} -> flatten_comments(children)
          _ -> []
        end

      [c | nested]
    end)
  end

  defp utc_to_datetime(nil), do: nil
  defp utc_to_datetime(val) when is_float(val), do: DateTime.from_unix!(trunc(val))
  defp utc_to_datetime(val) when is_integer(val), do: DateTime.from_unix!(val)
  defp utc_to_datetime(_), do: nil

  @doc """
  v1 does not support programmatic posting.
  Reddit's public API requires OAuth credentials that are not yet wired.
  Returns {:error, :posting_not_supported}.
  """
  @spec post(term(), String.t(), String.t()) :: {:error, :posting_not_supported}
  def post(_credential, _thread_id, _body), do: {:error, :posting_not_supported}
end
