defmodule MarketMySpec.Engagements do
  @moduledoc """
  Public boundary for the account-scoped engagement-finder domain.

  External callers — MCP tools, LiveViews — interact with this module
  exclusively. Internal repository and orchestrator modules are not part of
  the public API.

  ## Venues

  Venues represent platform locations (subreddits, ElixirForum categories)
  the finder will search, scoped to an account.

  ## Threads

  Threads are ingested from source platforms and cached locally with a
  freshness window (see `ThreadsRepository`).

  ## Touchpoints

  Touchpoints record each engagement comment after it has been posted back
  to the platform.

  ## Source Credentials

  Per-account OAuth tokens for write-capable sources. v1 ships read-only
  adapters, so credential functions return `:not_implemented` until a
  write-capable adapter and migration land.
  """

  alias MarketMySpec.Engagements.Posting
  alias MarketMySpec.Engagements.Search
  alias MarketMySpec.Engagements.ThreadsRepository
  alias MarketMySpec.Engagements.TouchpointsRepository
  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Engagements.VenuesRepository
  alias MarketMySpec.Users.Scope

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  @doc """
  Fans out the keyword `query` across all enabled venues in the account scope.

  Accepts an optional `:venue` keyword to restrict search to a single venue
  identifier. Returns a map with `:candidates` and `:failures`.
  """
  @spec search(Scope.t(), String.t(), keyword()) :: Search.result()
  def search(%Scope{} = scope, query, opts \\ []) when is_binary(query) do
    Search.search(scope, query, opts)
  end

  # ---------------------------------------------------------------------------
  # Posting
  # ---------------------------------------------------------------------------

  @doc """
  Embeds a UTM-tracked link into `body` and creates a Touchpoint record.

  The `link_target` bare URL is replaced with a UTM-enriched URL derived from
  the thread's source and source_thread_id. The resulting polished body and
  metadata are persisted as a Touchpoint scoped to the account.

  Returns `{:ok, touchpoint}` on success or `{:error, changeset}` on failure.
  """
  @spec post_comment(Scope.t(), map(), String.t(), String.t()) ::
          {:ok, MarketMySpec.Engagements.Touchpoint.t()} | {:error, Ecto.Changeset.t()}
  def post_comment(%Scope{} = scope, thread, body, link_target)
      when is_binary(body) and is_binary(link_target) do
    polished_body = Posting.embed_utm_link(thread, body, link_target)

    attrs = %{
      thread_id: Map.get(thread, :id),
      comment_url: Map.get(thread, :url, ""),
      polished_body: polished_body,
      link_target: link_target,
      posted_at: DateTime.utc_now()
    }

    TouchpointsRepository.create_touchpoint(scope, attrs)
  end

  # ---------------------------------------------------------------------------
  # Venues
  # ---------------------------------------------------------------------------

  @doc """
  Returns all venues for the account in the given scope.

  Pass an optional `source` atom (`:reddit` or `:elixirforum`) to filter.
  """
  @spec list_venues(Scope.t(), Venue.source() | nil) :: [Venue.t()]
  defdelegate list_venues(scope, source \\ nil), to: VenuesRepository

  @doc """
  Persists a new Venue for the account in the given scope.

  Returns `{:ok, venue}` on success or `{:error, changeset}` on failure.
  """
  @spec create_venue(Scope.t(), map()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create_venue(scope, attrs), to: VenuesRepository

  @doc """
  Updates an existing venue by id, scoped to the account.

  Returns `{:ok, venue}`, `{:error, :not_found}`, or `{:error, changeset}`.
  """
  @spec update_venue(Scope.t(), integer(), map()) ::
          {:ok, Venue.t()} | {:error, :not_found | Ecto.Changeset.t()}
  defdelegate update_venue(scope, id, attrs), to: VenuesRepository

  @doc """
  Deletes a venue by id, scoped to the account.

  Returns `{:ok, venue}` or `{:error, :not_found}`.
  """
  @spec delete_venue(Scope.t(), integer()) :: {:ok, Venue.t()} | {:error, :not_found}
  defdelegate delete_venue(scope, id), to: VenuesRepository

  # ---------------------------------------------------------------------------
  # Threads
  # ---------------------------------------------------------------------------

  @doc """
  Returns the cached Thread for (scope, venue, thread_id) when fresh;
  otherwise fetches from the source adapter, persists, and returns it.

  Returns `{:ok, thread}` or `{:error, reason}`.
  """
  @spec get_or_fetch_thread(Scope.t(), Venue.t(), String.t()) ::
          {:ok, MarketMySpec.Engagements.Thread.t()} | {:error, term()}
  defdelegate get_or_fetch_thread(scope, venue, thread_id), to: ThreadsRepository

  @doc """
  Returns the Thread by its UUID id, scoped to the account.

  Returns `{:ok, thread}` when found, `{:error, :not_found}` when missing
  or belonging to a different account.
  """
  @spec get_thread_by_id(Scope.t(), Ecto.UUID.t()) ::
          {:ok, MarketMySpec.Engagements.Thread.t()} | {:error, :not_found}
  defdelegate get_thread_by_id(scope, thread_id), to: ThreadsRepository

  @doc """
  Returns all threads for the account in the given scope, ordered by
  `fetched_at` descending.
  """
  @spec list_threads(Scope.t()) :: [MarketMySpec.Engagements.Thread.t()]
  defdelegate list_threads(scope), to: ThreadsRepository

  # ---------------------------------------------------------------------------
  # Touchpoints
  # ---------------------------------------------------------------------------

  @doc """
  Persists a new Touchpoint for the account in the given scope.

  Returns `{:ok, touchpoint}` or `{:error, changeset}`.
  """
  @spec create_touchpoint(Scope.t(), map()) ::
          {:ok, MarketMySpec.Engagements.Touchpoint.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create_touchpoint(scope, attrs), to: TouchpointsRepository

  @doc """
  Persists a new staged Touchpoint for the account in the given scope.

  Staged touchpoints do not require `comment_url` or `posted_at` — those
  are populated when the user submits the live comment URL.

  Returns `{:ok, touchpoint}` or `{:error, changeset}`.
  """
  @spec create_staged_touchpoint(Scope.t(), map()) ::
          {:ok, MarketMySpec.Engagements.Touchpoint.t()} | {:error, Ecto.Changeset.t()}
  defdelegate create_staged_touchpoint(scope, attrs), to: TouchpointsRepository

  @doc """
  Returns all touchpoints for the account in the given scope,
  ordered by `posted_at` descending.
  """
  @spec list_touchpoints(Scope.t()) :: [MarketMySpec.Engagements.Touchpoint.t()]
  defdelegate list_touchpoints(scope), to: TouchpointsRepository

  # ---------------------------------------------------------------------------
  # Source Credentials
  # ---------------------------------------------------------------------------

  @doc """
  Lists enabled source credentials for an account.

  v1 returns an empty list — write-capable adapters and the `source_credentials`
  table are not yet implemented.
  """
  @spec list_source_credentials(Scope.t()) :: []
  def list_source_credentials(%Scope{}) do
    []
  end

  @doc """
  Creates or updates an OAuth credential for an account and source.

  v1 returns `{:error, :not_implemented}` — write-capable adapters and the
  `source_credentials` table are not yet implemented.
  """
  @spec upsert_source_credential(Scope.t(), atom(), map()) ::
          {:error, :not_implemented}
  def upsert_source_credential(%Scope{}, _source, _attrs) do
    {:error, :not_implemented}
  end
end
