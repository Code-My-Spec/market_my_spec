defmodule MarketMySpecSpex.Story739.Criterion6531Spex do
  @moduledoc """
  Story 739 — Criterion 6531 — Zero LLM completion calls from MMS.
  TODO: rewrite using ReqCassette with embeddings-only allow-list.
  """

  use MarketMySpecSpex.Case

  spex "Full pipeline run issues zero LLM completion calls; only embeddings allowed" do
    scenario "Stubbed pending ReqCassette wiring" do
      given_ "TODO", context, do: {:ok, context}
      when_ "TODO", context, do: {:ok, context}
      then_ "TODO", context, do: {:ok, context}
    end
  end
end
