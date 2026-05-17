defmodule MarketMySpec.Engagements.Source.ElixirForum do
  @moduledoc """
  ElixirForum (Discourse) Source adapter.

  Validates category slug (and optional tag filter), pulls latest topics from
  category JSON endpoints with optional tag scoping, fetches full topic JSON
  and normalizes into the internal Thread schema.

  v1 does not support programmatic posting — `post/3` returns
  `{:error, :posting_not_supported}` per the v1 read-only design decision.

  ## Venue identifier format

  - Bare category slug: `"phoenix"`, `"elixir"`, `"questions"`
  - Category slug with tag: `"phoenix:livebook"`, `"elixir:phoenix-1-7"`

  Rejected: empty string, whitespace-only, containing `/`, multiple `:`,
  bare `:` prefix or suffix, or full URLs.

  ## HTTP

  Tests inject stubs via the `:elixirforum_req_options` application env key,
  mirroring the pattern used by the Reddit adapter. See `HTTP.elixirforum_client/0`.
  """

  @behaviour MarketMySpec.Engagements.Source

  alias MarketMySpec.Engagements.HTTP

  @base_url "https://elixirforum.com"
  @snippet_length 280

  @doc """
  Validates ElixirForum venue identifier format.

  Accepts:
  - `"phoenix"` — bare category slug
  - `"phoenix:livebook"` — category slug with tag filter

  Rejects:
  - Empty or whitespace-only strings
  - Strings containing `/`
  - Strings with leading or trailing `:`
  - Strings with more than one `:` (multi-colon)
  - Full URLs (contain `://`)
  - Strings containing spaces
  """
  @spec validate_venue(String.t()) :: :ok | {:error, String.t()}
  def validate_venue(identifier) when is_binary(identifier) do
    trimmed = String.trim(identifier)

    cond do
      trimmed == "" ->
        {:error, "ElixirForum venue identifier must not be empty or whitespace"}

      String.contains?(trimmed, "://") ->
        {:error, "ElixirForum venue identifier must be a category slug, not a full URL"}

      String.contains?(trimmed, "/") ->
        {:error, "ElixirForum venue identifier must not contain slashes"}

      String.contains?(trimmed, " ") ->
        {:error, "ElixirForum venue identifier must not contain spaces"}

      String.starts_with?(trimmed, ":") or String.ends_with?(trimmed, ":") ->
        {:error, "ElixirForum venue identifier must not start or end with a colon"}

      length(String.split(trimmed, ":")) > 2 ->
        {:error,
         "ElixirForum venue identifier must be 'slug' or 'slug:tag', not multiple colons"}

      true ->
        :ok
    end
  end

  def validate_venue(_identifier), do: {:error, "ElixirForum venue identifier must be a string"}

  @doc """
  Searches an ElixirForum category for latest topics via the Discourse
  `/c/<slug>/<id>/l/latest.json` endpoint (with optional `?tag=<tag>` filter).

  Discourse requires a numeric category id in the path; this adapter resolves
  it from the bare slug by fetching `/categories.json` once and caching the
  slug→id map in `:persistent_term`. On cache hit the search is a single
  request; on cache miss the search is two requests (categories lookup
  + latest topics).

  Returns `{:ok, %{candidates: [candidate], next_cursor: nil}}` on HTTP 200,
  or `{:error, reason}` on non-200 / network failure / unknown slug.

  Candidates carry the canonical shape:
  `source_thread_id, title, source, url, score, reply_count, recency, snippet`.
  """
  @spec search(map(), String.t(), keyword()) ::
          {:ok, %{candidates: [map()], next_cursor: nil | String.t()}} | {:error, term()}
  def search(venue, _query, _opts \\ []) when is_map(venue) do
    {slug, tag} = parse_identifier(venue.identifier)

    with {:ok, category_id} <- resolve_category_id(slug) do
      path = "/c/#{slug}/#{category_id}/l/latest.json"
      params = if tag, do: [tag: tag], else: []

      case Req.get(HTTP.elixirforum_client(), url: path, params: params) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          topics =
            body
            |> get_in(["topic_list", "topics"])
            |> List.wrap()
            |> Enum.map(&normalize_topic(&1, slug, category_id))
            |> Enum.reject(&is_nil/1)

          {:ok, %{candidates: topics, next_cursor: nil}}

        {:ok, %Req.Response{status: status}} ->
          {:error, {:http_status, status}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Cache key for the slug→id map in :persistent_term.
  @categories_key {__MODULE__, :categories_by_slug}

  # Resolves a category slug to a numeric Discourse category id. Hits
  # `/categories.json` on the first call (per VM), caches the slug→id map
  # in :persistent_term, and serves all subsequent lookups from memory.
  defp resolve_category_id(slug) do
    case lookup_cached(slug) do
      {:ok, id} ->
        {:ok, id}

      :miss ->
        case fetch_categories() do
          {:ok, map} ->
            :persistent_term.put(@categories_key, map)

            case Map.fetch(map, slug) do
              {:ok, id} -> {:ok, id}
              :error -> {:error, {:unknown_category, slug}}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp lookup_cached(slug) do
    case :persistent_term.get(@categories_key, nil) do
      nil ->
        :miss

      map ->
        case Map.fetch(map, slug) do
          {:ok, id} -> {:ok, id}
          :error -> :miss
        end
    end
  end

  defp fetch_categories do
    case Req.get(HTTP.elixirforum_client(), url: "/categories.json") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        map =
          body
          |> get_in(["category_list", "categories"])
          |> List.wrap()
          |> Enum.reduce(%{}, fn cat, acc ->
            slug = Map.get(cat, "slug")
            id = Map.get(cat, "id")
            if is_binary(slug) and is_integer(id), do: Map.put(acc, slug, id), else: acc
          end)

        {:ok, map}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches full Discourse topic JSON and normalizes into Thread schema.

  Returns `{:ok, map}` on HTTP 200, `{:error, reason}` on non-200 or
  network failure.
  """
  @spec get_thread(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_thread(_venue, thread_id) when is_binary(thread_id) do
    case Req.get(HTTP.elixirforum_client(), url: "/t/#{thread_id}.json") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, normalize_thread(thread_id, body)}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  v1 does not support programmatic posting.
  Returns `{:error, :posting_not_supported}`.
  """
  @spec post(term(), String.t(), String.t()) :: {:error, :posting_not_supported}
  def post(_credential, _thread_id, _body), do: {:error, :posting_not_supported}

  # Split "slug:tag" → {"slug", "tag"} or "slug" → {"slug", nil}
  defp parse_identifier(identifier) when is_binary(identifier) do
    case String.split(identifier, ":", parts: 2) do
      [slug, tag] -> {slug, tag}
      [slug] -> {slug, nil}
    end
  end

  defp normalize_topic(topic, _category_slug, _category_id) when is_map(topic) do
    id = Map.get(topic, "id")

    if is_nil(id) do
      nil
    else
      source_thread_id = to_string(id)
      title = Map.get(topic, "title", "")
      slug = Map.get(topic, "slug", source_thread_id)
      reply_count = Map.get(topic, "reply_count") || Map.get(topic, "posts_count", 0)
      views = Map.get(topic, "views", 0)
      last_posted_at = Map.get(topic, "last_posted_at")
      excerpt = Map.get(topic, "excerpt", "")

      url = "#{@base_url}/t/#{slug}/#{source_thread_id}"

      %{
        "source_thread_id" => source_thread_id,
        "title" => title,
        "source" => "elixirforum",
        "url" => url,
        "score" => views,
        "reply_count" => reply_count,
        "recency" => last_posted_at,
        "snippet" => snippet(excerpt)
      }
    end
  end

  defp normalize_topic(_, _, _), do: nil

  defp normalize_thread(thread_id, body) do
    title = Map.get(body, "title", "Thread #{thread_id}")
    slug = Map.get(body, "slug", thread_id)
    url = "#{@base_url}/t/#{slug}/#{thread_id}"

    posts =
      body
      |> get_in(["post_stream", "posts"])
      |> List.wrap()

    op_body =
      posts
      |> List.first()
      |> case do
        %{"cooked" => cooked} -> cooked
        _ -> ""
      end

    %{
      title: title,
      op_body: op_body,
      url: url,
      comment_tree: %{"children" => []},
      raw_payload: body
    }
  end

  defp snippet(text) when is_binary(text), do: String.slice(text, 0, @snippet_length)
  defp snippet(_), do: ""
end
