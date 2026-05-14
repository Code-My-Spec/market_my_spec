# MarketMySpec.Engagements.Touchpoint

Saved post-back record. Account-scoped. Fields: account_id, thread_id (FK to Thread), comment_url, polished_body, link_target, posted_at. One-to-many from Thread.

## Type

schema

## Fields

- account_id — foreign key to Account
- thread_id — foreign key to Thread; the thread this comment was posted in reply to
- comment_url — live URL of the posted comment on the source platform
- polished_body — the final comment body that was posted, including embedded UTM link
- link_target — the URL that was embedded in the polished body (the UTM-tracked destination)
- posted_at — datetime when the comment was successfully posted
