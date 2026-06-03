defmodule MarketMySpec.Chat.NullToolRegistry do
  @moduledoc """
  The v0 `ToolRegistry` implementation: no tools.

  `list_tools/1` returns `[]`, so the model is called with no tools and never
  emits a tool call — the reply is a pure text stream (R7/E7.1). Swapped for an
  Mcp-backed implementation later with no other changes.
  """

  @behaviour MarketMySpec.Chat.ToolRegistry

  alias MarketMySpec.Chat.Conversation

  @impl MarketMySpec.Chat.ToolRegistry
  @spec list_tools(Conversation.t()) :: []
  def list_tools(_conversation), do: []
end
