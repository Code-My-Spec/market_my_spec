# MarketMySpec.Chat.Message

A single message in a conversation. role (:user | :assistant), content, and status (:streaming | :complete | :error) driving the in-progress and error affordances. User messages persist immediately on send (R1). Assistant messages persist on :stream_done with normalized metadata (R6): provider, model, input_tokens, output_tokens, cost (nullable), finish_reason, and response_id (nullable) — all derivable from ReqLLM's StreamResponse.usage/1 and finish_reason/1.

## Type

schema
