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

        next_cursor = get_in(body, ["data", "after"])
        {:ok, %{candidates: candidates, next_cursor: next_cursor}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_child(%{"data" => data}) when is_map(data) do
    %{
      "title" => Map.get(data, "title", ""),
      "source" => "reddit",
      "url" => "https://www.reddit.com" <> (Map.get(data, "permalink") || ""),
      "score" => Map.get(data, "score") || Map.get(data, "ups") || 0,
      "reply_count" => Map.get(data, "num_comments", 0),
      "recency" => Map.get(data, "created_utc"),
      "snippet" => (Map.get(data, "selftext") || "") |> snippet()
    }
  end

  defp normalize_child(other) do
    %{
      "title" => "",
      "source" => "reddit",
      "url" => "https://www.reddit.com",
      "score" => 0,
      "reply_count" => 0,
      "recency" => nil,
      "snippet" => inspect(other) |> snippet()
    }
  end

  defp snippet(text) when is_binary(text), do: String.slice(text, 0, @snippet_length)
  defp snippet(_), do: ""

  @doc """
  Fetches full Reddit thread JSON and normalizes into Thread schema preserving
  comment hierarchy.

  NOTE: Scaffold — story 706 implements the live fetch.
  """
  @spec get_thread(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_thread(_venue, thread_id) do
    {:ok,
     %{
       id: thread_id,
       source: "reddit",
       title: "Thread #{thread_id}",
       op_body: "",
       comments: []
     }}
  end

  @doc """
  v1 does not support programmatic posting.
  Reddit's public API requires OAuth credentials that are not yet wired.
  Returns {:error, :posting_not_supported}.
  """
  @spec post(term(), String.t(), String.t()) :: {:error, :posting_not_supported}
  def post(_credential, _thread_id, _body), do: {:error, :posting_not_supported}
end
