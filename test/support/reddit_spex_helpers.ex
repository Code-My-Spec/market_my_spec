defmodule MarketMySpecSpex.RedditHelpers do
  @moduledoc """
  Shared helpers for story-705 / story-706 Reddit spex.

  Mirrors the OAuthHelpers pattern (test/support/oauth_spex_helpers.ex):
  loads a real-shape Reddit search response cassette and mutates the
  per-test fields (children, query, subreddit) before writing the cassette
  to disk. The spex wraps the call under test in `with_reddit_cassette/2`,
  which injects ReqCassette's plug into `Engagements.HTTP.reddit_client/0`
  via app env for the duration of the call.

  ## Recording the shape cassette

  The shape cassette `test/cassettes/reddit/search_shape.json` is a
  ReqCassette dump of one anonymous `GET /r/elixir/search.json?q=phoenix&...`
  call with two listing results. To re-record:

      MIX_ENV=test mix run -e '
        Application.put_env(:req_cassette, :mode, :record)
        File.rm("test/cassettes/reddit/search_shape.json")
        ReqCassette.with_cassette "reddit/search_shape", [mode: :record], fn plug ->
          Req.get!(MarketMySpec.Engagements.HTTP.reddit_client(),
            url: "/r/elixir/search.json",
            params: [q: "phoenix", restrict_sr: 1, sort: "new", limit: 2],
            plug: plug)
        end
      '

  Cassettes are anonymous-read so there are no auth headers to scrub.
  """

  use Boundary, deps: [MarketMySpec]

  import ReqCassette

  @cassette_dir "test/cassettes/reddit"
  @shape_path Path.join(@cassette_dir, "search_shape.json")

  @doc """
  Runs `fun` with ReqCassette's plug injected into `Engagements.HTTP.reddit_client/0`.

  The cassette at `test/cassettes/reddit/<name>.json` is matched on
  method + URI (including query string). Requests outside the cassette
  raise in `:replay` mode (the project default in `config/test.exs`).
  """
  @spec with_reddit_cassette(String.t(), (-> any())) :: any()
  def with_reddit_cassette(cassette_name, fun) do
    with_cassette cassette_name, cassette_opts(), fn plug ->
      with_reddit_plug(plug, fun)
    end
  end

  defp cassette_mode do
    case System.get_env("REQ_CASSETTE_MODE") do
      "record" -> :record
      "bypass" -> :bypass
      "replay" -> :replay
      _ -> Application.get_env(:req_cassette, :mode, :replay)
    end
  end

  defp cassette_opts do
    [
      cassette_dir: @cassette_dir,
      mode: cassette_mode(),
      # ReqCassette's `:uri` matches path only; `:query` is a separate
      # matcher. Include both so pagination cursors (which differ only in
      # the `after` query param) match the right interaction.
      match_requests_on: [:method, :uri, :query],
      filter_request_headers: ["authorization"],
      # ReqCassette in :record mode builds a fresh Req without the
      # caller's base config — forward the TLS opts so HTTPS works.
      req_options: [
        connect_options: [transport_opts: tls_transport_opts()]
      ]
    ]
  end

  defp tls_transport_opts do
    cond do
      Code.ensure_loaded?(CAStore) -> [cacertfile: CAStore.file_path()]
      true -> [cacerts: :public_key.cacerts_get()]
    end
  rescue
    _ -> []
  end

  defp with_reddit_plug(plug, fun) do
    previous = Application.get_env(:market_my_spec, :reddit_req_options, [])
    # Disable retries in tests so 429/5xx cassettes don't sleep for 60s.
    Application.put_env(:market_my_spec, :reddit_req_options, plug: plug, retry: false)

    try do
      fun.()
    after
      if previous == [] do
        Application.delete_env(:market_my_spec, :reddit_req_options)
      else
        Application.put_env(:market_my_spec, :reddit_req_options, previous)
      end
    end
  end

  @doc """
  Builds a per-test cassette by loading the shape and replacing the
  single interaction's request/response with caller-supplied values.

  Writes the cassette to `test/cassettes/reddit/<cassette_name>.json`
  and schedules `File.rm` on test exit.

  ## Options

  - `:subreddit` (default `"elixir"`) — venue identifier; goes into the URL.
  - `:query` (default `"elixir"`) — `q` query param.
  - `:sort` (default `"new"`).
  - `:limit` (default `25`).
  - `:after` (default `nil`) — pagination cursor; included in URL when set.
  - `:status` (default `200`).
  - `:children` (default `[]`) — list of post-data maps to put under
    `data.children[*].data`. Each map is merged into a baseline child
    so callers only need to override the fields they care about
    (`title`, `score`, `num_comments`, `created_utc`, `subreddit`,
    `permalink`, `id`, `selftext`).
  - `:after_cursor` (default `nil`) — value placed at `data.after` of
    the response (cursor pointer to next page).
  """
  @spec build_search_cassette!(String.t(), keyword()) :: :ok
  def build_search_cassette!(cassette_name, opts \\ []) do
    subreddit = Keyword.get(opts, :subreddit, "elixir")
    query = Keyword.get(opts, :query, "elixir")
    sort = Keyword.get(opts, :sort, "new")
    limit = Keyword.get(opts, :limit, 25)
    after_param = Keyword.get(opts, :after, nil)
    status = Keyword.get(opts, :status, 200)
    children = Keyword.get(opts, :children, [])
    after_cursor = Keyword.get(opts, :after_cursor, nil)

    shape = load_shape!()
    interaction = List.first(shape["interactions"]) || %{}

    request =
      interaction
      |> Map.get("request", %{})
      |> Map.put("uri", "https://www.reddit.com/r/#{subreddit}/search.json")
      |> Map.put("query_string", build_query(query, sort, limit, after_param))
      |> Map.put("method", "GET")
      |> Map.put("body", "")
      |> Map.put("body_type", "text")

    response =
      case status do
        200 ->
          body = build_search_body(children, after_cursor)

          interaction
          |> Map.get("response", %{})
          |> Map.put("status", 200)
          |> Map.put("body_type", "json")
          |> Map.put("body_json", body)

        429 ->
          %{
            "status" => 429,
            "body_type" => "text",
            "body" => "rate limited",
            "headers" => %{
              "content-type" => ["text/plain"],
              "x-ratelimit-reset" => ["60"]
            }
          }

        other ->
          %{
            "status" => other,
            "body_type" => "text",
            "body" => "error",
            "headers" => %{"content-type" => ["text/plain"]}
          }
      end

    cassette = %{
      "version" => Map.get(shape, "version", "1.0"),
      "interactions" => [
        %{
          "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "request" => request,
          "response" => response
        }
      ]
    }

    write_cassette!(cassette_name, cassette)
  end

  @doc """
  Builds a multi-interaction cassette from a list of `build_search_cassette!/2`-style
  option keywords. Each element produces one interaction in the order given.
  Useful for spex that exercise two venues, two pages, or success + failure
  in one orchestrator call.
  """
  @spec build_multi_cassette!(String.t(), [keyword()]) :: :ok
  def build_multi_cassette!(cassette_name, interactions_opts) do
    shape = load_shape!()
    shape_interaction = List.first(shape["interactions"]) || %{}

    interactions =
      Enum.map(interactions_opts, fn opts ->
        single = build_one_interaction(shape_interaction, opts)
        single
      end)

    cassette = %{
      "version" => Map.get(shape, "version", "1.0"),
      "interactions" => interactions
    }

    write_cassette!(cassette_name, cassette)
  end

  defp build_one_interaction(shape_interaction, opts) do
    subreddit = Keyword.get(opts, :subreddit, "elixir")
    query = Keyword.get(opts, :query, "elixir")
    sort = Keyword.get(opts, :sort, "new")
    limit = Keyword.get(opts, :limit, 25)
    after_param = Keyword.get(opts, :after, nil)
    status = Keyword.get(opts, :status, 200)
    children = Keyword.get(opts, :children, [])
    after_cursor = Keyword.get(opts, :after_cursor, nil)

    request =
      shape_interaction
      |> Map.get("request", %{})
      |> Map.put("uri", "https://www.reddit.com/r/#{subreddit}/search.json")
      |> Map.put("query_string", build_query(query, sort, limit, after_param))
      |> Map.put("method", "GET")
      |> Map.put("body", "")
      |> Map.put("body_type", "text")

    response =
      case status do
        200 ->
          body = build_search_body(children, after_cursor)

          shape_interaction
          |> Map.get("response", %{})
          |> Map.put("status", 200)
          |> Map.put("body_type", "json")
          |> Map.put("body_json", body)

        429 ->
          %{
            "status" => 429,
            "body_type" => "text",
            "body" => "rate limited",
            "headers" => %{
              "content-type" => ["text/plain"],
              "x-ratelimit-reset" => ["60"]
            }
          }

        other ->
          %{
            "status" => other,
            "body_type" => "text",
            "body" => "error",
            "headers" => %{"content-type" => ["text/plain"]}
          }
      end

    %{
      "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "request" => request,
      "response" => response
    }
  end

  defp build_query(query, sort, limit, nil) do
    URI.encode_query(q: query, restrict_sr: 1, sort: sort, limit: limit)
  end

  defp build_query(query, sort, limit, after_param) do
    URI.encode_query(q: query, restrict_sr: 1, sort: sort, limit: limit, after: after_param)
  end

  defp build_search_body(children, after_cursor) do
    %{
      "kind" => "Listing",
      "data" => %{
        "after" => after_cursor,
        "before" => nil,
        "dist" => length(children),
        "modhash" => "",
        "geo_filter" => "",
        "facets" => %{},
        "children" => Enum.map(children, &wrap_child/1)
      }
    }
  end

  defp wrap_child(child_overrides) do
    base = %{
      "title" => "Thread #{System.unique_integer([:positive])}",
      "subreddit" => "elixir",
      "permalink" => "/r/elixir/comments/abc123/some_thread/",
      "url" => "https://www.reddit.com/r/elixir/comments/abc123/some_thread/",
      "score" => 0,
      "ups" => 0,
      "num_comments" => 0,
      "created_utc" => 1_700_000_000.0,
      "selftext" => "",
      "name" => "t3_abc123",
      "id" => "abc123",
      "author" => "anon"
    }

    merged = Map.merge(base, stringify_keys(child_overrides))

    %{"kind" => "t3", "data" => merged}
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp load_shape! do
    case File.read(@shape_path) do
      {:ok, body} ->
        Jason.decode!(body)

      {:error, :enoent} ->
        # Synthesize a minimal shape if the recorded one is missing — keeps
        # tests authorable before the first real recording. Re-record per
        # the moduledoc to capture real Reddit response headers.
        %{
          "version" => "1.0",
          "interactions" => [
            %{
              "request" => %{
                "method" => "GET",
                "uri" => "https://www.reddit.com/r/elixir/search.json",
                "query_string" => "",
                "headers" => %{
                  "user-agent" => ["market_my_spec/0.1 by /u/johns10davenport"]
                },
                "body" => "",
                "body_type" => "text"
              },
              "response" => %{
                "status" => 200,
                "headers" => %{"content-type" => ["application/json; charset=UTF-8"]},
                "body_type" => "json",
                "body_json" => %{
                  "kind" => "Listing",
                  "data" => %{"after" => nil, "children" => []}
                }
              }
            }
          ]
        }
    end
  end

  defp write_cassette!(cassette_name, cassette) do
    File.mkdir_p!(@cassette_dir)
    path = Path.join(@cassette_dir, cassette_name <> ".json")
    File.write!(path, Jason.encode!(cassette, pretty: true))
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
    :ok
  end

  # ============================================================================
  # /comments/<id>.json helpers — for story-706 GetThread spex
  # ============================================================================

  @doc """
  Builds a cassette for Reddit's `GET /comments/<source_thread_id>.json` (the
  deep-read endpoint) — returns the canonical array-of-two-listings payload
  (`[post_listing, comments_listing]`).

  ## Options

  - `:source_thread_id` (required) — Reddit post id, e.g. `"abc123"` (the part
    between `/comments/` and `/` in a Reddit URL).
  - `:limit` (default `25`) — `limit` query param the adapter sends.
  - `:sort` (default `"confidence"`) — Reddit's default sort for comment trees.
  - `:after` (default `nil`) — pagination cursor; included in URL when set.
  - `:status` (default `200`).
  - `:post` (default `%{}`) — overrides for the post `t3` data map. Common keys:
    `title`, `selftext`, `author`, `score`, `num_comments`, `created_utc`,
    `permalink`, `url`, `subreddit`.
  - `:comments` (default `[]`) — list of comment specs. Each spec is a map
    with optional `:replies` (list of nested comment specs). Each carries
    `body`, `author`, `score`, `created_utc`, `depth` (auto-computed),
    `id` defaults from index.

  Cassettes are anonymous-read — no auth headers to scrub.
  """
  @spec build_comments_cassette!(String.t(), keyword()) :: :ok
  def build_comments_cassette!(cassette_name, opts) do
    source_thread_id = Keyword.fetch!(opts, :source_thread_id)
    limit = Keyword.get(opts, :limit, 25)
    sort = Keyword.get(opts, :sort, "confidence")
    after_param = Keyword.get(opts, :after, nil)
    status = Keyword.get(opts, :status, 200)
    post_overrides = Keyword.get(opts, :post, %{})
    comments = Keyword.get(opts, :comments, [])

    request = %{
      "method" => "GET",
      "uri" => "https://www.reddit.com/comments/#{source_thread_id}.json",
      "query_string" => build_comments_query(sort, limit, after_param),
      "headers" => %{
        "user-agent" => ["market_my_spec/0.1 by /u/johns10davenport"]
      },
      "body" => "",
      "body_type" => "text"
    }

    response = build_comments_response(status, source_thread_id, post_overrides, comments)

    cassette = %{
      "version" => "1.0",
      "interactions" => [
        %{
          "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "request" => request,
          "response" => response
        }
      ]
    }

    write_cassette!(cassette_name, cassette)
  end

  @doc """
  Multi-interaction variant for spex that need two `GET /comments/<id>.json`
  calls in a single cassette (e.g., outside-window refresh after a cached
  read, or pagination). Each element is the same option set as
  `build_comments_cassette!/2`.
  """
  @spec build_multi_comments_cassette!(String.t(), [keyword()]) :: :ok
  def build_multi_comments_cassette!(cassette_name, interactions_opts) do
    # Pair each interaction with the next one so we can use the next
    # interaction's `after` request param as the current response's cursor.
    opts_with_next =
      Enum.zip(interactions_opts, Enum.drop(interactions_opts, 1) ++ [nil])

    interactions =
      Enum.map(opts_with_next, fn {opts, next_opts} ->
        source_thread_id = Keyword.fetch!(opts, :source_thread_id)
        limit = Keyword.get(opts, :limit, 25)
        sort = Keyword.get(opts, :sort, "confidence")
        after_param = Keyword.get(opts, :after, nil)
        status = Keyword.get(opts, :status, 200)
        post_overrides = Keyword.get(opts, :post, %{})
        comments = Keyword.get(opts, :comments, [])

        # The response cursor for this interaction is either the `after`
        # param that the NEXT request sends (look-ahead), or auto-derived
        # when comments exceed limit.
        explicit_after_cursor = Keyword.get(opts, :after_cursor, nil)
        next_after = if next_opts, do: Keyword.get(next_opts, :after, nil), else: nil
        response_cursor = explicit_after_cursor || next_after

        request = %{
          "method" => "GET",
          "uri" => "https://www.reddit.com/comments/#{source_thread_id}.json",
          "query_string" => build_comments_query(sort, limit, after_param),
          "headers" => %{
            "user-agent" => ["market_my_spec/0.1 by /u/johns10davenport"]
          },
          "body" => "",
          "body_type" => "text"
        }

        response =
          if status == 200 do
            build_comments_response_200(source_thread_id, post_overrides, comments, limit, response_cursor)
          else
            build_comments_response(status, source_thread_id, post_overrides, comments)
          end

        %{
          "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "request" => request,
          "response" => response
        }
      end)

    cassette = %{
      "version" => "1.0",
      "interactions" => interactions
    }

    write_cassette!(cassette_name, cassette)
  end

  defp build_comments_query(sort, limit, nil) do
    URI.encode_query(sort: sort, limit: limit)
  end

  defp build_comments_query(sort, limit, after_param) do
    URI.encode_query(sort: sort, limit: limit, after: after_param)
  end

  # Builds a comments response with optional pagination cursor.
  # When `after_cursor` is nil, auto-derives one if comments exceed `limit`.
  defp build_comments_response_200(source_thread_id, post_overrides, comments, limit, after_cursor) do
    post_listing = build_post_listing(source_thread_id, post_overrides)

    # Simulate Reddit's server-side limit: if comments exceed limit, truncate
    # and auto-derive an `after` cursor from the last included comment's id.
    {page_comments, auto_cursor} =
      if length(comments) > limit do
        page = Enum.take(comments, limit)
        last_id = page |> List.last() |> (fn spec ->
          m = stringify_keys(spec)
          Map.get(m, "id", "c#{limit - 1}")
        end).()
        {page, "t1_#{last_id}"}
      else
        {comments, nil}
      end

    final_cursor = after_cursor || auto_cursor
    comments_listing = build_comments_listing(page_comments, final_cursor)

    %{
      "status" => 200,
      "headers" => %{"content-type" => ["application/json; charset=UTF-8"]},
      "body_type" => "json",
      "body_json" => [post_listing, comments_listing]
    }
  end

  defp build_comments_response(200, source_thread_id, post_overrides, comments) do
    build_comments_response_200(source_thread_id, post_overrides, comments, 25, nil)
  end

  defp build_comments_response(429, _id, _post, _comments) do
    %{
      "status" => 429,
      "body_type" => "text",
      "body" => "rate limited",
      "headers" => %{
        "content-type" => ["text/plain"],
        "x-ratelimit-reset" => ["60"],
        "retry-after" => ["60"]
      }
    }
  end

  defp build_comments_response(status, _id, _post, _comments) do
    %{
      "status" => status,
      "body_type" => "text",
      "body" => "error",
      "headers" => %{"content-type" => ["text/plain"]}
    }
  end

  defp build_post_listing(source_thread_id, post_overrides) do
    post_data = build_post_data(source_thread_id, post_overrides)

    %{
      "kind" => "Listing",
      "data" => %{
        "after" => nil,
        "before" => nil,
        "children" => [%{"kind" => "t3", "data" => post_data}]
      }
    }
  end

  defp build_post_data(source_thread_id, overrides) do
    base = %{
      "id" => source_thread_id,
      "name" => "t3_" <> source_thread_id,
      "title" => "Thread #{source_thread_id}",
      "selftext" => "",
      "author" => "anon",
      "score" => 1,
      "num_comments" => 0,
      "created_utc" => 1_700_000_000.0,
      "subreddit" => "elixir",
      "permalink" => "/r/elixir/comments/#{source_thread_id}/_/",
      "url" => "https://www.reddit.com/r/elixir/comments/#{source_thread_id}/_/"
    }

    Map.merge(base, stringify_keys(overrides))
  end

  defp build_comments_listing(comments, after_cursor) do
    children =
      comments
      |> Enum.with_index()
      |> Enum.map(fn {spec, idx} -> wrap_comment(spec, idx, 0) end)

    %{
      "kind" => "Listing",
      "data" => %{
        "after" => after_cursor,
        "before" => nil,
        "children" => children
      }
    }
  end

  defp wrap_comment(spec, idx, depth) do
    spec_map = stringify_keys(spec)
    replies = Map.get(spec_map, "replies", [])
    id = Map.get(spec_map, "id", "c#{depth}_#{idx}")

    reply_children =
      replies
      |> Enum.with_index()
      |> Enum.map(fn {child_spec, child_idx} -> wrap_comment(child_spec, child_idx, depth + 1) end)

    replies_listing =
      case reply_children do
        [] ->
          ""

        children ->
          %{
            "kind" => "Listing",
            "data" => %{"after" => nil, "before" => nil, "children" => children}
          }
      end

    data = %{
      "id" => id,
      "name" => "t1_" <> id,
      "body" => Map.get(spec_map, "body", "Comment body #{id}"),
      "author" => Map.get(spec_map, "author", "anon_#{idx}"),
      "score" => Map.get(spec_map, "score", 1),
      "created_utc" => Map.get(spec_map, "created_utc", 1_700_000_000.0 + idx),
      "depth" => depth,
      "parent_id" => Map.get(spec_map, "parent_id", "t3_unknown"),
      "replies" => replies_listing
    }

    %{"kind" => "t1", "data" => data}
  end
end
