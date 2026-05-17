# MarketMySpecWeb.TouchpointLive.Show

Single-touchpoint detail view. Renders polished_body, angle, state, comment_url, posted_at, link_target, and parent thread context. Provides three forms/actions: (1) "Mark posted" — paste live comment URL + posted_at, calls Engagements.update_touchpoint/3 with state :posted (rejects without comment_url per R3); (2) "Abandon" — calls Engagements.update_touchpoint/3 with state :abandoned, preserves all fields (R4); (3) "Delete" — calls Engagements.delete_touchpoint/2, removes row entirely (R9). Same context functions back the MCP update_touchpoint and delete_touchpoint tools so UI and agent transitions produce identical persisted state (R5).

## Type

liveview

## Dependencies

- MarketMySpec.Engagements
