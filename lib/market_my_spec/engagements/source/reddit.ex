defmodule MarketMySpec.Engagements.Source.Reddit do
  @moduledoc """
  Reddit Source adapter.

  Validates subreddit name format, searches via Reddit's per-subreddit search API,
  fetches full thread JSON and normalizes into the internal Thread schema (preserving
  comment hierarchy), and posts comments via the Reddit submit-comment endpoint using
  account-scoped OAuth credentials.

  NOTE: This is a scaffold. Real API integration is pending Story 705/706/707.
  v1 does not support programmatic posting — post/3 returns
  {:error, :posting_not_supported} per the v1 read-only design decision.
  """

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
  Searches subreddit via Reddit per-subreddit search API and returns candidate thread list.

  NOTE: Scaffold — returns empty results until HTTP client integration is complete.
  """
  @spec search(map(), String.t()) :: {:ok, list()} | {:error, term()}
  def search(_venue, _query), do: {:ok, []}

  @doc """
  Fetches full Reddit thread JSON and normalizes into Thread schema preserving comment
  hierarchy.

  NOTE: Scaffold — returns a stub thread until HTTP client integration is complete.
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
