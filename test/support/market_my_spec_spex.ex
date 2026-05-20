defmodule MarketMySpecSpex do
  @moduledoc false
  # Spex test helpers (OAuthHelpers, RedditHelpers, ElixirForumHelpers) need
  # direct access to MarketMySpec internals (OAuthStateStore, req options, etc.)
  # for test infrastructure setup — they are test bridges, not production callers.
  # MarketMySpec is listed here so sub-modules of MarketMySpecSpex that serve
  # as test infrastructure can access it. BDD spec modules themselves should
  # still route state access through MarketMySpecSpex.Fixtures where possible.
  use Boundary,
    top_level?: true,
    deps: [MarketMySpec, MarketMySpecSpex.Fixtures, MarketMySpecWeb]
end
