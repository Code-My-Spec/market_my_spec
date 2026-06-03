# MarketMySpec.Chat.ToolRegistry

Behaviour defining the tool seam the Runner consults around each LLM call (R7). Single callback list_tools/1 returning the tools available for a conversation. Shaped so a later Mcp implementation can point at marketmyspec.com/mcp and surface run_search, list_touchpoints, stage_response, etc. without any change to the LiveView or PubSub contract.

## Type

behaviour
