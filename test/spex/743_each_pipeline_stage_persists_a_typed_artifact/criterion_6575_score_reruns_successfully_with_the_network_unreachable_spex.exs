defmodule MarketMySpecSpex.Story743.Criterion6575Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6575 — Score reruns successfully with the network unreachable.

  TODO: rewrite using ReqCassette in replay-only mode.
  """

  use MarketMySpecSpex.Case

  spex "Score reruns make zero outbound HTTP requests" do
    scenario "Stubbed pending ReqCassette wiring" do
      given_ "TODO", context, do: {:ok, context}
      when_ "TODO", context, do: {:ok, context}
      then_ "TODO", context, do: {:ok, context}
    end
  end
end
