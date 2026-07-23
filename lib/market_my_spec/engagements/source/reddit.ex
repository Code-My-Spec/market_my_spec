defmodule MarketMySpec.Engagements.Source.Reddit do
  @moduledoc """
  Reddit Source adapter — RSS (Atom) edition.

  As of mid-2026 Reddit requires OAuth credentials for the JSON listing/
  search API (`*.json`), and serves HTTP 403 to anonymous + datacenter
  callers. The public **Atom feeds** (`*.rss`) are still served anonymously
  and — confirmed empirically — are reachable from datacenter IPs that get
  403 on the JSON endpoints. So every read funnels through `.rss`.

  ## Transport: request/fetch/normalize

  Reads are split into three composable steps so the *same* RSS logic runs
  on the server and inside the MMS Agent binary (both compile from this
  tree — see `MarketMySpecAgent.Channel.Client`):

    1. `build_search_request/3` / `build_thread_request/2` — pure. Produce a
       JSON-safe request map (`path` + ordered `params`) that can ride the
       agent channel unchanged.
    2. `fetch/2` — the transport. Acquires a rate-limit token, issues the
       `Req` call, returns `{:ok, %{"status" => …, "body" => …}}`. This is
       what the agent runs on its residential IP.
    3. `normalize_search/1` / `normalize_thread/2` — pure parsing, always
       server-side so there is one parser to keep in sync.

  `search/3` and `get_thread/3` compose all three for the direct path.
  The queued path (see `Engagements.FetchQueue`) builds the request on the
  server, ships it to the agent for step 2, and normalizes the response
  when it comes back.

  Reddit meters ~1 request per ~60s window per IP, so whichever side owns
  the socket also owns the rate limiter — the server throttles its own
  direct calls, the agent throttles its own. Never both for one request.

  ## What RSS gives up vs JSON

  Atom feeds carry no vote score and no comment count, and comment feeds
  are **flat** (no nested reply tree, no per-comment score). Accordingly:

    * search candidates carry `score: 0` and `reply_count: 0`
    * `get_thread` returns a flat `comment_tree` (every comment `depth: 0`,
      `score: 0`)

  Search pagination is derived client-side: Reddit honors `?after=<fullname>`
  on `.rss`, so `next_cursor` is the last entry's `t3_` fullname whenever a
  full page (== `limit`) comes back, else `nil`.

  ## get_thread/2, post/3

  `get_thread` reads `/comments/<id>.rss`. `post/3` remains unsupported
  (no anonymous write surface).
  """

  @behaviour MarketMySpec.Engagements.Source

  import SweetXml, only: [sigil_x: 2]

  require Logger

  alias MarketMySpec.Engagements.HTTP
  alias MarketMySpec.Engagements.RateLimiter

  @snippet_length 280
  @page_limit 25

  # How long an adapter call will wait for a rate-limit token before giving
  # up with `{:error, :rate_limit_timeout}`. Kept under the orchestrator's
  # per-venue task timeout (Search.fan_out is 15s) so a throttled request
  # surfaces a clean "Rate limited" reason instead of being killed mid-flight.
  @rate_limit_timeout 10_000

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
  Searches a subreddit via Reddit's per-subreddit `search.rss` Atom feed.

  Returns `{:ok, %{candidates: [candidate], next_cursor: nil | string}}` on
  HTTP 200, or `{:error, reason}` on non-200 / network failure.

  Accepts an optional `:cursor` opt for pagination — passed as Reddit's
  `after` query param.
  """
  @spec search(map(), String.t(), keyword()) ::
          {:ok, %{candidates: [map()], next_cursor: nil | String.t()}} | {:error, term()}
  def search(venue, query, opts \\ []) when is_binary(query) do
    venue
    |> build_search_request(query, opts)
    |> fetch(opts)
    |> case do
      {:ok, %{"status" => 200, "body" => body}} -> {:ok, normalize_search(body)}
      {:ok, %{"status" => status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  # ── Request construction ─────────────────────────────────────────────
  #
  # Pure and JSON-safe: `params` is an ordered list of ["key", "value"]
  # pairs, not a map, because the encoded query string must be byte-stable
  # across the server and the agent (test cassettes match on full URL, and
  # a map would reorder). `label` is for logging only.

  @doc """
  Builds the JSON-safe request map for a subreddit search feed.

  The map is the unit of work handed to the agent: it fully determines the
  URL, so the agent never constructs Reddit URLs itself.
  """
  @spec build_search_request(map(), String.t(), keyword()) :: map()
  def build_search_request(venue, query, opts \\ []) when is_binary(query) do
    %{
      "kind" => "search",
      "path" => "/r/#{venue.identifier}/search.rss",
      "params" => search_params(query, Keyword.get(opts, :cursor)),
      "label" => "r/#{venue.identifier}"
    }
  end

  @doc """
  Builds the JSON-safe request map for a thread's flat comment feed.
  """
  @spec build_thread_request(String.t(), keyword()) :: map()
  def build_thread_request(source_thread_id, opts \\ []) do
    %{
      "kind" => "thread",
      "path" => "/comments/#{source_thread_id}.rss",
      "params" => thread_params(opts),
      "source_thread_id" => source_thread_id,
      "label" => "comments/#{source_thread_id}"
    }
  end

  @doc """
  Executes a request map against Reddit and returns the raw response.

  This is the only function that touches the network, and it is what the
  MMS Agent runs on its residential IP — the agent calls it with
  `rate_limit_timeout:` sized to Reddit's window, having first acquired
  from its own limiter instance.

  Opts:

    * `:rate_limit` — acquire a token before the call (default `true`).
      Pass `false` when the caller already paced the request (the agent's
      serial worker does its own acquire, so the server must not
      double-throttle a dispatched fetch).
    * `:rate_limit_timeout` — how long to wait for a token
      (default `#{@rate_limit_timeout}` ms).
    * `:rate_limit_server` — which `RateLimiter` instance to acquire from
      (default the registered one). The agent and the server each run their
      own, since they meter different IPs.

  Returns `{:ok, %{"status" => integer, "body" => binary}}` for any HTTP
  response including 429 — status interpretation is the caller's job, so
  the agent can ship a 429 back untouched. Returns `{:error, reason}` for
  transport failures and `{:error, :rate_limit_timeout}` when no token
  frees up in time.
  """
  @spec fetch(map(), keyword()) :: {:ok, %{String.t() => term()}} | {:error, term()}
  def fetch(%{"path" => path} = request, opts \\ []) do
    label = Map.get(request, "label", path)

    with :ok <- maybe_acquire_token(label, opts) do
      case Req.get(HTTP.reddit_client(), url: path, params: req_params(request)) do
        {:ok, %Req.Response{status: 429}} ->
          Logger.warning("reddit rate-limit: REAL Reddit 429 for #{label}")
          {:ok, %{"status" => 429, "body" => ""}}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:ok, %{"status" => status, "body" => to_xml(body)}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Params ride the wire as ["k", "v"] pairs; Req wants tuples.
  defp req_params(%{"params" => params}) when is_list(params) do
    Enum.map(params, fn
      [k, v] -> {k, v}
      {k, v} -> {k, v}
    end)
  end

  defp req_params(_), do: []

  defp maybe_acquire_token(label, opts) do
    if Keyword.get(opts, :rate_limit, true) do
      acquire_token(
        label,
        Keyword.get(opts, :rate_limit_timeout, @rate_limit_timeout),
        Keyword.get(opts, :rate_limit_server, RateLimiter)
      )
    else
      :ok
    end
  end

  # Acquire a Reddit rate-limit token, logging how long we waited and whether
  # we gave up. This instrumentation is how we tell self-inflicted local
  # throttling (acquire timeout) apart from real Reddit 429s, and how we size
  # the bucket — the "waited Nms" lines reveal real contention under a fan-out.
  defp acquire_token(label, timeout, server) do
    start = System.monotonic_time(:millisecond)
    result = RateLimiter.acquire(:reddit, timeout, server)
    waited = System.monotonic_time(:millisecond) - start

    case result do
      :ok ->
        if waited >= 250 do
          Logger.info("reddit rate-limit: waited #{waited}ms for token (#{label})")
        end

        :ok

      {:error, :rate_limit_timeout} = err ->
        Logger.warning(
          "reddit rate-limit: LOCAL acquire timeout after #{waited}ms for #{label} " <>
            "(our limiter gave up, not a Reddit 429)"
        )

        err
    end
  end

  defp search_params(query, cursor) do
    base = [
      ["q", to_string(query)],
      ["restrict_sr", "1"],
      ["sort", "new"],
      ["limit", to_string(@page_limit)]
    ]

    if is_binary(cursor) and cursor != "",
      do: base ++ [["after", cursor]],
      else: base
  end

  # A malformed feed from one venue degrades to zero candidates rather than
  # crashing the multi-venue fan-out (xmerl raises an `exit`, which the
  # orchestrator's `rescue` would not catch).
  defp normalize_feed(xml) do
    entries = xml |> parse_xml() |> SweetXml.xpath(~x"//entry"l)

    candidates =
      entries
      |> Enum.map(&normalize_entry/1)
      |> Enum.reject(&is_nil/1)

    %{candidates: candidates, next_cursor: next_cursor(entries, candidates)}
  rescue
    _ -> %{candidates: [], next_cursor: nil}
  catch
    _, _ -> %{candidates: [], next_cursor: nil}
  end

  # Reddit RSS exposes no server cursor. We derive one: when a full page
  # (== limit) comes back there is probably more, so hand back the last
  # entry's fullname (the `t3_` id, which Reddit's `after` param expects).
  # A short page means end-of-listing → nil.
  defp next_cursor(entries, candidates) do
    if length(candidates) >= @page_limit do
      entries
      |> List.last()
      |> entry_raw_id()
      |> case do
        "" -> nil
        id -> id
      end
    else
      nil
    end
  end

  defp normalize_entry(entry) do
    source_thread_id = entry |> entry_raw_id() |> strip_fullname()

    if source_thread_id == "" do
      nil
    else
      %{
        "source_thread_id" => source_thread_id,
        "title" => node_text(entry, ~x"./title/text()"sl),
        "source" => "reddit",
        "url" => entry |> SweetXml.xpath(~x"./link/@href"s) |> to_string(),
        "score" => 0,
        "reply_count" => 0,
        "recency" => entry_timestamp(entry),
        "snippet" => entry |> node_text(~x"./content/text()"sl) |> strip_html() |> snippet()
      }
    end
  end

  @doc """
  Fetches a Reddit thread's `/comments/<id>.rss` Atom feed and normalizes it
  into a Thread-compatible map.

  Atom comment feeds are flat, so the returned `comment_tree` is a single
  level (`%{"children" => [...]}`) with every comment at `depth: 0` and
  `score: 0` (RSS carries neither nesting nor vote counts). `op_body` and
  `title` come from the post entry (`t3_`); `last_activity_at` is the newest
  entry timestamp. `comments_cursor` is always `nil`.

  Returns `{:ok, map}` on HTTP 200, `{:error, reason}` otherwise.
  """
  @spec get_thread(map() | nil, String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_thread(_venue, source_thread_id, opts \\ []) do
    source_thread_id
    |> build_thread_request(opts)
    |> fetch(opts)
    |> case do
      {:ok, %{"status" => 200, "body" => body}} ->
        {:ok, normalize_thread(source_thread_id, body)}

      {:ok, %{"status" => status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parses a search feed body into the `%{candidates:, next_cursor:}` envelope.

  Always runs server-side (the agent ships raw XML back), so there is a
  single parser regardless of which IP fetched the bytes.
  """
  @spec normalize_search(binary()) :: %{candidates: [map()], next_cursor: nil | String.t()}
  def normalize_search(body), do: normalize_feed(to_xml(body))

  @doc """
  Parses a comment feed body into a Thread-compatible map. See `get_thread/3`
  for the shape and the `normalization_error` degradation path.
  """
  @spec normalize_thread(String.t(), binary()) :: map()
  def normalize_thread(source_thread_id, body),
    do: normalize_thread_feed(source_thread_id, to_xml(body))

  defp thread_params(opts) do
    sort = Keyword.get(opts, :sort, "confidence")
    limit = Keyword.get(opts, :limit, @page_limit)
    after_param = Keyword.get(opts, :after)

    base = [["sort", to_string(sort)], ["limit", to_string(limit)]]

    if is_binary(after_param) and after_param != "",
      do: base ++ [["after", after_param]],
      else: base
  end

  # Parsing is wrapped so a malformed feed still persists raw_payload and
  # surfaces a `:normalization_error` — the GetThread tool then keeps the
  # thread's prior comment_tree rather than clobbering it (story 706).
  defp normalize_thread_feed(source_thread_id, xml) do
    parse_thread_feed(source_thread_id, xml)
  rescue
    error ->
      %{
        raw_payload: %{"feed" => xml},
        comment_tree: nil,
        last_activity_at: nil,
        comments_cursor: nil,
        normalization_error: Exception.message(error)
      }
  catch
    kind, reason ->
      %{
        raw_payload: %{"feed" => xml},
        comment_tree: nil,
        last_activity_at: nil,
        comments_cursor: nil,
        normalization_error: "#{kind}: #{inspect(reason)}"
      }
  end

  defp parse_thread_feed(source_thread_id, xml) do
    doc = parse_xml(xml)
    entries = SweetXml.xpath(doc, ~x"//entry"l)
    feed_title = node_text(doc, ~x"/feed/title/text()"sl)

    {post_entries, comment_entries} =
      Enum.split_with(entries, fn e -> String.starts_with?(entry_raw_id(e), "t3_") end)

    post = List.first(post_entries)

    op_body =
      if post, do: post |> node_text(~x"./content/text()"sl) |> strip_html(), else: ""

    post_title = if post, do: node_text(post, ~x"./title/text()"sl), else: ""

    title =
      cond do
        post_title != "" -> post_title
        feed_title != "" -> feed_title
        true -> "Thread #{source_thread_id}"
      end

    comments =
      comment_entries
      |> Enum.map(&normalize_flat_comment/1)
      |> Enum.reject(&is_nil/1)

    last_activity_at =
      entries
      |> Enum.map(&entry_datetime/1)
      |> Enum.reject(&is_nil/1)
      |> max_datetime()

    %{
      title: title,
      op_body: op_body,
      comment_tree: %{"children" => comments},
      raw_payload: %{"feed" => xml},
      last_activity_at: last_activity_at,
      comments_cursor: nil
    }
  end

  defp normalize_flat_comment(entry) do
    id = entry |> entry_raw_id() |> strip_fullname()

    if id == "" do
      nil
    else
      %{
        "id" => id,
        "author" => entry |> node_text(~x"./author/name/text()"sl) |> strip_user_prefix(),
        "body" => entry |> node_text(~x"./content/text()"sl) |> strip_html(),
        "score" => 0,
        "created_utc" => entry_timestamp(entry),
        "depth" => 0
      }
    end
  end

  @doc """
  v1 does not support programmatic posting.
  Reddit's write API requires OAuth credentials that are not yet wired.
  Returns {:error, :posting_not_supported}.
  """
  @spec post(term(), String.t(), String.t()) :: {:error, :posting_not_supported}
  def post(_credential, _thread_id, _body), do: {:error, :posting_not_supported}

  # ── parsing helpers ──────────────────────────────────────────────────

  # Req leaves XML bodies as binaries; the agent transport hands back a
  # string (or, defensively, an already-parsed term we stringify).
  defp to_xml(body) when is_binary(body), do: body
  defp to_xml(body), do: to_string(body)

  # `quiet: true` keeps xmerl from writing an error_logger entry on malformed
  # input — it still throws (we catch it), but without the noisy log line.
  defp parse_xml(xml), do: SweetXml.parse(xml, quiet: true)

  defp entry_raw_id(nil), do: ""
  defp entry_raw_id(entry), do: entry |> node_text(~x"./id/text()"sl) |> String.trim()

  defp strip_fullname("t3_" <> rest), do: rest
  defp strip_fullname("t1_" <> rest), do: rest
  defp strip_fullname(other), do: other

  defp strip_user_prefix("/u/" <> user), do: user
  defp strip_user_prefix("/user/" <> user), do: user
  defp strip_user_prefix(other), do: other

  # Prefer <published>, fall back to <updated>; returns the raw ISO8601 string
  # (search recency is recomputed downstream from the persisted Thread).
  defp entry_timestamp(entry) do
    case node_text(entry, ~x"./published/text()"sl) do
      "" -> node_text(entry, ~x"./updated/text()"sl)
      published -> published
    end
  end

  defp entry_datetime(entry) do
    entry |> entry_timestamp() |> parse_iso8601()
  end

  defp parse_iso8601(ts) when is_binary(ts) and ts != "" do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp parse_iso8601(_), do: nil

  defp max_datetime([]), do: nil

  defp max_datetime(datetimes) do
    Enum.reduce(datetimes, fn dt, acc ->
      if DateTime.compare(dt, acc) == :gt, do: dt, else: acc
    end)
  end

  # Concatenate every text node under `path` (xmerl splits text across
  # entity-reference boundaries, so the first node alone can truncate).
  defp node_text(node, path) do
    node
    |> SweetXml.xpath(path)
    |> Enum.map_join("", &to_string/1)
  end

  defp snippet(text) when is_binary(text), do: String.slice(text, 0, @snippet_length)
  defp snippet(_), do: ""

  defp strip_html(nil), do: ""

  defp strip_html(html) when is_binary(html) do
    html
    |> String.replace(~r{</?[^>]*>}, " ")
    |> decode_entities()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp decode_entities(string) do
    string
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&#x27;", "'")
    |> String.replace("&nbsp;", " ")
    |> decode_numeric_entities()
    |> String.replace("&amp;", "&")
  end

  defp decode_numeric_entities(string) do
    Regex.replace(~r/&#(\d+);/, string, fn _, digits ->
      <<String.to_integer(digits)::utf8>>
    end)
  rescue
    _ -> string
  end
end
