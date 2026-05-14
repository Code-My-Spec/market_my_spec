defmodule MarketMySpec.Engagements.Source.ElixirForum do
  @moduledoc """
  ElixirForum (Discourse) Source adapter.

  Validates category id (and optional tag filter), pulls latest topics from category
  JSON endpoints with optional tag scoping, fetches full topic JSON and normalizes
  into the internal Thread schema, and posts replies via the Discourse posts endpoint
  using account-scoped credentials.

  NOTE: This is a scaffold. Real API integration is pending Story 705/706/707.
  v1 does not support programmatic posting — post/3 returns
  {:error, :posting_not_supported} per the v1 read-only design decision.
  """

  @doc """
  Validates ElixirForum venue identifier (category id with optional tag).
  Format: "category-slug" or "category-slug:tag".
  """
  @spec validate_venue(String.t()) :: :ok | {:error, String.t()}
  def validate_venue(identifier) when is_binary(identifier) do
    if String.length(identifier) > 0 do
      :ok
    else
      {:error, "ElixirForum venue identifier must not be empty"}
    end
  end

  def validate_venue(_identifier), do: {:error, "ElixirForum venue identifier must be a string"}

  @doc """
  Fetches latest topics from Discourse category JSON endpoints with optional tag scoping.

  NOTE: Scaffold — returns empty results until HTTP client integration is complete.
  """
  @spec search(map(), String.t()) :: {:ok, list()} | {:error, term()}
  def search(_venue, _query), do: {:ok, []}

  @doc """
  Fetches full Discourse topic JSON and normalizes into Thread schema.

  NOTE: Scaffold — returns a stub thread until HTTP client integration is complete.
  """
  @spec get_thread(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_thread(_venue, thread_id) do
    {:ok,
     %{
       id: thread_id,
       source: "elixirforum",
       title: "Thread #{thread_id}",
       op_body: "",
       comments: []
     }}
  end

  @doc """
  v1 does not support programmatic posting.
  ElixirForum's Discourse API requires credentials that are not yet wired.
  Returns {:error, :posting_not_supported}.
  """
  @spec post(term(), String.t(), String.t()) :: {:error, :posting_not_supported}
  def post(_credential, _thread_id, _body), do: {:error, :posting_not_supported}
end
