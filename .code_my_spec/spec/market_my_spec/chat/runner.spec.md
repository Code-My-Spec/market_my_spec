# MarketMySpec.Chat.Runner

The only ReqLLM-aware module (mirrors livellm's LlmRunner). Runs inside a Task.Supervisor task so the LiveView never blocks (R3). Steps: (1) build the request from thread history plus the conversation's provider/model; (2) call ToolRegistry.list_tools/1 and pass tools to ReqLLM (v0: []); (3) stream via ReqLLM.stream_text/3, mapping StreamChunk :content -> {:stream_chunk}, :thinking -> {:stream_reasoning}, broadcasting on "chat:#{chat_id}"; (4) tool-call branch — on a :tool_call chunk, dispatch via the registry, feed the result back, continue (v0-unreachable but tested with a stub); (5) on completion persist the assistant Message with metadata and broadcast {:stream_done}; (6) on provider/stream failure broadcast {:stream_error} for a recoverable error state (R8). Updates ActiveTasks as chunks accumulate.

## Type

module

## Dependencies

- MarketMySpec.Chat.Conversation
- MarketMySpec.Chat.Message
- MarketMySpec.Chat.ActiveTasks
- MarketMySpec.Chat.ToolRegistry
