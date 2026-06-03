# MarketMySpec.Chat.NullToolRegistry

The v0 ToolRegistry implementation. list_tools/1 returns []. With no tools, ReqLLM is called with no tools and the model never emits a tool call, so the loop is a pure text stream (R7/E7.1). Swapped for an Mcp implementation later with no other changes.

## Type

module

## Dependencies

- MarketMySpec.Chat.ToolRegistry
