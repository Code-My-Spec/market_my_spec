defmodule MarketMySpecTest do
  @moduledoc false
  use Boundary, top_level?: true, deps: [MarketMySpec], exports: :all
end
