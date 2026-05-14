# MarketMySpec.Engagements.Thread

Ingested thread record. Account-scoped. Fields: account_id, source, source_thread_id, url, title, op_body, comment_tree (jsonb, normalized hierarchy), raw_payload (jsonb, original platform JSON for re-render/debug), fetched_at. Repeat fetches within a freshness window read this row instead of re-hitting the platform.

## Type

schema

## Fields

- account_id — foreign key to Account
- source — enum (reddit | elixirforum), identifies the originating platform
- source_thread_id — platform-native thread identifier
- url — canonical URL to the thread on the source platform
- title — thread title / post title
- op_body — original post body text
- comment_tree — jsonb, normalized comment hierarchy for display and LLM processing
- raw_payload — jsonb, original platform API response for re-render and debugging
- fetched_at — datetime of last fetch; used for freshness-window cache check
