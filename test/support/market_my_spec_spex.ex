defmodule MarketMySpecSpex do
  @moduledoc false
  use Boundary,
    top_level?: true,
    deps: [MarketMySpec, MarketMySpecSpex.Fixtures, MarketMySpecWeb]
end
