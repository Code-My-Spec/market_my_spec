defmodule MarketMySpec.Engagements.Source do
  @moduledoc """
  Behaviour contract every engagement source adapter implements.

  Adapters (e.g. `MarketMySpec.Engagements.Source.Reddit` and
  `MarketMySpec.Engagements.Source.ElixirForum`) plug into this contract so
  orchestrators like `MarketMySpec.Engagements.Search` and
  `MarketMySpec.Engagements.Posting` can fan-out across sources without
  knowing the platform-specific details.

  ## v1 read-only posture

  v1 ships Reddit and ElixirForum as **read-only** adapters. The `post/3`
  callback is present in the contract so future write-capable adapters can
  implement it without an interface change. Read-only adapters return
  `{:error, :posting_not_supported}` from `post/3`.
  """

  alias MarketMySpec.Engagements.Thread
  alias MarketMySpec.Engagements.Venue

  @type credential :: term()

  @doc """
  Validates a source-specific venue identifier string.

  Returns `:ok` when the identifier is valid for the adapter, or
  `{:error, reason}` when the format is unacceptable. This is called by
  `Venue.changeset/2` to enforce per-source rules at persistence time.

  ### Examples

      iex> Reddit.validate_venue("elixir")
      :ok

      iex> Reddit.validate_venue("bad name!")
      {:error, "Invalid subreddit name ..."}

  """
  @callback validate_venue(identifier :: String.t()) :: :ok | {:error, String.t()}

  @doc """
  Searches the given venue for threads matching the query string.

  Returns `{:ok, candidates}` where `candidates` is a list of candidate
  thread maps, or `{:error, reason}` on failure. An empty list is a valid
  successful result when no matching threads exist.

  ### Parameters

  - `venue` — a `MarketMySpec.Engagements.Venue` struct describing which
    platform location to search.
  - `query` — the keyword or phrase to search for.

  """
  @callback search(venue :: Venue.t(), query :: String.t()) ::
              {:ok, list(map())} | {:error, term()}

  @doc """
  Fetches and normalizes a single thread by venue and platform thread id.

  Returns `{:ok, thread_map}` where `thread_map` is a normalized
  `MarketMySpec.Engagements.Thread`-compatible map with the comment
  hierarchy intact, or `{:error, reason}` on failure.

  ### Parameters

  - `venue` — a `MarketMySpec.Engagements.Venue` struct for the platform
    location the thread lives in.
  - `thread_id` — the platform-native thread identifier string.

  """
  @callback get_thread(venue :: Venue.t(), thread_id :: String.t()) ::
              {:ok, Thread.t() | map()} | {:error, term()}

  @doc """
  Posts a comment body using account-scoped credentials and returns the
  live comment URL.

  Returns `{:ok, comment_url}` on success, where `comment_url` is the
  canonical URL of the newly created comment on the source platform.

  Read-only adapters (all v1 adapters) return
  `{:error, :posting_not_supported}`.

  ### Parameters

  - `credential` — account-scoped credential (OAuth token, API key, etc.)
    obtained from `MarketMySpec.Engagements.SourceCredential`.
  - `thread_id` — the platform-native thread identifier string.
  - `body` — the comment body text to post.

  """
  @callback post(credential :: credential(), thread_id :: String.t(), body :: String.t()) ::
              {:ok, String.t()} | {:error, :posting_not_supported | term()}
end
