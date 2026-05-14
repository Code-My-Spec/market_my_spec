defmodule MarketMySpec.EngagementsFixtures do
  @moduledoc """
  Fixtures for the MarketMySpec.Engagements context — Threads and Touchpoints.

  Both fixtures are account-scoped via the caller's `%Scope{}` and persist
  a real row via `MarketMySpec.Repo`. They are admin-shortcut state for
  specs that need an ingested Thread or staged Touchpoint as a precondition
  before driving the UI / MCP tool surface.
  """

  alias MarketMySpec.Engagements.Thread
  alias MarketMySpec.Engagements.Touchpoint
  alias MarketMySpec.Repo

  @doc """
  Inserts a Thread scoped to `scope.active_account_id`.

  Accepts overrides via the `attrs` map. Defaults produce a Reddit-source thread
  with unique `source_thread_id` and a current `fetched_at` so freshness-window
  cache reads find it.
  """
  @spec thread_fixture(MarketMySpec.Users.Scope.t(), map() | keyword()) :: Thread.t()
  def thread_fixture(scope, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)
    source_thread_id = "thread-#{System.unique_integer([:positive])}"

    defaults = %{
      account_id: scope.active_account_id,
      source: :reddit,
      source_thread_id: source_thread_id,
      url: "https://www.reddit.com/r/elixir/comments/#{source_thread_id}",
      title: "Engagement opportunity #{source_thread_id}",
      op_body: "An OP body that the agent can analyze.",
      comment_tree: %{"children" => []},
      raw_payload: %{"source_thread_id" => source_thread_id},
      fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    merged =
      defaults
      |> Map.merge(attrs)
      |> Map.update(:source, :reddit, &cast_source/1)

    %Thread{}
    |> Thread.changeset(merged)
    |> Repo.insert!()
  end

  @doc """
  Inserts a Touchpoint scoped to `scope.active_account_id` and the given thread.

  Defaults to a staged touchpoint (no `comment_url` / `posted_at`). Pass
  `:comment_url` and `:posted_at` (or set both) to land directly in posted state.
  """
  @spec touchpoint_fixture(MarketMySpec.Users.Scope.t(), Thread.t(), map() | keyword()) ::
          Touchpoint.t()
  def touchpoint_fixture(scope, %Thread{} = thread, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    defaults = %{
      account_id: scope.active_account_id,
      thread_id: thread.id,
      polished_body: "A polished engagement comment body.",
      link_target: "https://codemyspec.com"
    }

    merged = Map.merge(defaults, attrs)

    changeset =
      if Map.get(merged, :comment_url) || Map.get(merged, :posted_at) do
        merged =
          merged
          |> Map.put_new(:posted_at, DateTime.utc_now() |> DateTime.truncate(:second))
          |> Map.put_new(:comment_url, "https://www.reddit.com/r/elixir/comments/posted-#{System.unique_integer([:positive])}")

        Touchpoint.changeset(%Touchpoint{}, merged)
      else
        Touchpoint.staged_changeset(%Touchpoint{}, merged)
      end

    Repo.insert!(changeset)
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(attrs) when is_map(attrs), do: attrs

  defp cast_source(value) when is_atom(value), do: value
  defp cast_source("reddit"), do: :reddit
  defp cast_source("elixirforum"), do: :elixirforum
  defp cast_source(other) when is_binary(other), do: String.to_existing_atom(other)
end
