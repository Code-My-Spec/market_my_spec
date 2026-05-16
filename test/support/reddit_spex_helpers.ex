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

  defp cassette_opts do
    [
      cassette_dir: @cassette_dir,
      mode: Application.get_env(:req_cassette, :mode, :replay),
      # ReqCassette's `:uri` matches path only; `:query` is a separate
      # matcher. Include both so pagination cursors (which differ only in
      # the `after` query param) match the right interaction.
      match_requests_on: [:method, :uri, :query],
      filter_request_headers: ["authorization"]
    ]
  end

  defp with_reddit_plug(plug, fun) do
    previous = Application.get_env(:market_my_spec, :reddit_req_options, [])
    Application.put_env(:market_my_spec, :reddit_req_options, plug: plug)

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
end
