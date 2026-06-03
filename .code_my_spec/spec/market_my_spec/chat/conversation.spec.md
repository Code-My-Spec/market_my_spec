# MarketMySpec.Chat.Conversation

A chat conversation scoped to the current_user's account (reuses existing MMS auth/scope). Holds the selected provider and model, which are changeable per conversation and apply to the next sent message (R5). Has many Messages ordered by insertion. The conversation id is the chat_id used in the PubSub topic "chat:#{chat_id}".

## Type

schema
