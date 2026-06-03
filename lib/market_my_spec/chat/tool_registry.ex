defmodule MarketMySpec.Chat.ToolRegistry do
  @moduledoc """
  The tool seam the Runner consults around each LLM call (R7).

  In v0 the only implementation — `MarketMySpec.Chat.NullToolRegistry` —
  returns `[]`, so ReqLLM is called with no tools and the loop is a pure text
  stream. The behaviour is shaped so a later `Mcp` implementation can point at
  `marketmyspec.com/mcp` and surface `run_search`, `list_touchpoints`,
  `stage_response`, etc. without any change to the LiveView or PubSub contract.
  """

  alias MarketMySpec.Chat.Conversation

  @doc """
  Returns the tools available for a conversation, ready to hand to ReqLLM.
  """
  @callback list_tools(Conversation.t()) :: [ReqLLM.Tool.t()]
end
