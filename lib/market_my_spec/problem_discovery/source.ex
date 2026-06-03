defmodule MarketMySpec.ProblemDiscovery.Source do
  @moduledoc """
  Pluggable data-source contract for the Gather stage (story 740).

  A Source takes a saved-search recipe (`%{source: source_name, query: q}`)
  and returns a list of `JobPosting` attribute maps the Pipeline can
  insert. The contract is intentionally tiny — one callback — so adding
  Reddit, LinkedIn, G2, or any other source is a one-file implementation
  plus a registry entry.

  `Pipeline.Gather` dispatches per `saved_search.source` to the right
  impl via the registry in this module. New sources register at compile
  time via `@behaviour MarketMySpec.ProblemDiscovery.Source` and an entry
  in `impl_for/1` below.
  """

  alias MarketMySpec.ProblemDiscovery.Source.Upwork

  @type saved_search :: %{source: String.t(), query: String.t()}
  @type opts :: keyword()
  @type posting_attrs :: map()

  @doc """
  Execute the source's native search for the given saved-search recipe.
  Returns a list of JobPosting attribute maps (without `frame_id`,
  `saved_search_index`, or `embedding` — those are filled in by
  `Pipeline.Gather` per row).

  Opts:
  - `:limit` — cap on results returned. Used in probe-mode Gather.
  """
  @callback search(saved_search(), opts()) ::
              {:ok, [posting_attrs()]} | {:error, term()}

  @doc """
  Resolve a saved-search's `source` string to the registered Source impl.
  Returns `{:error, :unknown_source}` when no impl is registered.
  """
  @spec impl_for(String.t()) :: {:ok, module()} | {:error, :unknown_source}
  def impl_for("upwork"), do: {:ok, Upwork}
  def impl_for(_other), do: {:error, :unknown_source}

  @doc """
  Convenience wrapper: resolve the impl and invoke `search/2` in one call.
  Pipeline.Gather uses this so it doesn't have to thread the impl module
  manually.
  """
  @spec search(saved_search(), opts()) ::
          {:ok, [posting_attrs()]} | {:error, term()}
  def search(%{source: source_name} = saved_search, opts \\ []) do
    with {:ok, impl} <- impl_for(source_name) do
      impl.search(saved_search, opts)
    end
  end
end
