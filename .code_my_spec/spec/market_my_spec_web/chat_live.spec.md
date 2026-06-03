# MarketMySpecWeb.ChatLive

The conversational chat surface (lifted from livellm's ChatLive), rendered with stream/3. On mount it loads the conversation's messages from the DB and checks ActiveTasks for in-flight state to restore partial assistant text + in-progress status (R4), then subscribes to "chat:#{chat_id}". Renders the thread, a header provider/model selector (R5), token/cost badges from persisted metadata (R6), and an input that stays unblocked while a reply streams (R1/R3). send_message persists the user message and spawns the Runner under Task.Supervisor — it issues no synchronous provider call. handle_info receives {:stream_chunk}/{:stream_reasoning}/{:stream_done}/{:stream_error} and updates the streamed message, including the recoverable error state with a retry affordance (R8).

## Type

liveview

## Dependencies

- MarketMySpec.Chat
- MarketMySpec.Chat.ActiveTasks
