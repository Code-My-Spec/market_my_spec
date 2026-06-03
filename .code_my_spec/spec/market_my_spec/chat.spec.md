# MarketMySpec.Chat

Conversational LLM chat context. Owns Conversation and Message entities and orchestrates streaming replies. The Runner is the only ReqLLM-aware module: it builds a request from thread history plus the conversation's provider/model, consults the ToolRegistry seam (empty in v0), streams via ReqLLM.stream_text/3, broadcasts the PubSub contract on "chat:#{chat_id}" ({:stream_chunk,:stream_reasoning,:stream_done,:stream_error}), persists the assistant message with normalized metadata, and dispatches the (v0-unreachable) tool-call branch. ActiveTasks (GenServer+ETS keyed by chat_id) holds in-flight streaming state so a remounting LiveView can recover partial text. LLM calls run under a Task.Supervisor so the LiveView never blocks. Built so MarketMySpec's own /mcp tools fill the ToolRegistry later without touching the LiveView or PubSub contract.

## Type

context

## Dependencies

- MarketMySpec.Chat.Conversation
- MarketMySpec.Chat.Message
- MarketMySpec.Chat.Runner
- MarketMySpec.Chat.ActiveTasks
- MarketMySpec.Chat.ToolRegistry
- MarketMySpec.Chat.NullToolRegistry
