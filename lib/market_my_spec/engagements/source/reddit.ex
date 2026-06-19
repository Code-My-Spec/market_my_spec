defmodule MarketMySpec.Engagements.Source.Reddit do
  @moduledoc """
  Reddit Source adapter — RSS (Atom) edition.

  As of mid-2026 Reddit requires OAuth credentials for the JSON listing/
  search API (`*.json`), and serves HTTP 403 to anonymous + datacenter
  callers. The public **Atom feeds** (`*.rss`) are still served anonymously
  and — confirmed empirically — are reachable from datacenter IPs that get
  403 on the JSON endpoints. So every read funnels through `.rss`.

  ## Transport

  All reads hit Reddit directly from the server via `Req` — RSS is served
  anonymously and reachable from datacenter IPs (verified on prod's Hetzner
  host), so no residential-IP proxy/agent is needed. No OAuth involved.

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
    with :ok <- acquire_token("r/#{venue.identifier}"),
         {:ok, %Req.Response{status: 200, body: body}} <-
           Req.get(HTTP.reddit_client(),
             url: "/r/#{venue.identifier}/search.rss",
             params: search_params(query, Keyword.get(opts, :cursor))
           ) do
      {:ok, normalize_feed(to_xml(body))}
    else
      {:error, :rate_limit_timeout} ->
        {:error, :rate_limit_timeout}

      {:ok, %Req.Response{status: 429}} ->
        Logger.warning("reddit rate-limit: REAL Reddit 429 for r/#{venue.identifier}")
        {:error, {:http_status, 429}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Acquire a Reddit rate-limit token, logging how long we waited and whether
  # we gave up. This instrumentation is how we tell self-inflicted local
  # throttling (acquire timeout) apart from real Reddit 429s, and how we size
  # the bucket — the "waited Nms" lines reveal real contention under a fan-out.
  defp acquire_token(label) do
    start = System.monotonic_time(:millisecond)
    result = RateLimiter.acquire(:reddit, @rate_limit_timeout)
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
    base = [q: query, restrict_sr: 1, sort: "new", limit: @page_limit]

    if is_binary(cursor) and cursor != "",
      do: base ++ [after: cursor],
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
    with :ok <- acquire_token("comments/#{source_thread_id}"),
         {:ok, %Req.Response{status: 200, body: body}} <-
           Req.get(HTTP.reddit_client(),
             url: "/comments/#{source_thread_id}.rss",
             params: thread_params(opts)
           ) do
      {:ok, normalize_thread_feed(source_thread_id, to_xml(body))}
    else
      {:error, :rate_limit_timeout} ->
        {:error, :rate_limit_timeout}

      {:ok, %Req.Response{status: 429}} ->
        Logger.warning("reddit rate-limit: REAL Reddit 429 for comments/#{source_thread_id}")
        {:error, {:http_status, 429}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp thread_params(opts) do
    sort = Keyword.get(opts, :sort, "confidence")
    limit = Keyword.get(opts, :limit, @page_limit)
    after_param = Keyword.get(opts, :after)

    base = [sort: sort, limit: limit]

    if is_binary(after_param) and after_param != "",
      do: base ++ [after: after_param],
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
