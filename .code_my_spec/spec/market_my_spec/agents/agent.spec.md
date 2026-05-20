# MarketMySpec.Agents.Agent

Paired agent binary record. Fields: user_id, name (user-supplied label), version (binary self-reported, e.g. "0.3.0"), status (:active | :revoked), last_seen_at, paired_at, revoked_at, encrypted_token (the long-lived secret used for channel join auth), token_hash (indexed lookup column for fast channel auth without decrypting). Owned by a single user — a user can pair multiple binaries, and all of that user's agents share one channel topic (`agents:<user_id>`). Account membership is many-to-many on user and orthogonal to Agent ownership; the Agent has no account_id.

## Type

schema
