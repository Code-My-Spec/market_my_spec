# `analytics-admin` MCP — `create_custom_dimension` description silently capped at 150 chars

Filed 2026-05-23. Surfaced during the CodeMySpec custom-dimension registration session.

## Problem

`mcp__analytics-admin__create_custom_dimension` accepts a `description` argument with no documented length limit in the tool docstring. Google Analytics Admin API enforces a hard 150-char cap server-side. Exceeding the cap returns:

```
%Tesla.Env{... status: 400, body: "{\"error\": {\"code\": 400, \"message\": \"The length of the value for the 'description' field exceeded the maximum limit of 150.\", \"status\": \"INVALID_ARGUMENT\"}}"}
```

That's a structured Google API error but the MCP wrapper surfaces it as a raw `Failed to create custom dimension: %Tesla.Env{...}` blob with no extracted message at the top level — the operator has to parse the body field to see the actual reason.

## Repro

Today's session:
- First `create_custom_dimension` for `harness` (description ~142 chars) — succeeded.
- Second `create_custom_dimension` for `location` (description ~190 chars) — failed with 400 + the cap error.
- Retried `location` with shortened description — succeeded.

Same cap presumably applies to `create_custom_metric` and `create_key_event` (untested).

## Acceptance criteria

1. **Document the 150-char cap** in the `create_custom_dimension` (and other create_* tools') docstring.
2. **Surface the API error cleanly** — instead of raising a raw `Tesla.Env` blob, parse the Google API error body and return a structured `{:error, %{code: 400, message: "...", status: "INVALID_ARGUMENT"}}` that the MCP renders as the human-readable message at the top of the response. Same shape for any other 4xx the Admin API returns.
3. **Optional client-side validation**: if `String.length(description) > 150`, return an early validation error without making the API round-trip. Mirrors the schema spirit.

## Out of scope

- Re-architecting the Google Admin API client. The error shape is fine; the MCP wrapper just needs to unwrap and surface the message.
- Per-field caps on other args (parameter_name has its own constraints, etc.). File separately if needed.

## Reference

- Caller-side log of the failure: `code_my_spec_marketing/.code_my_spec/knowledge/analytics-snapshots/analytics-snapshot-2026-05-23.md` (GA4 admin actions section).
- The two dimensions that did get created: `properties/508773792/customDimensions/14933011472` (`harness`), `properties/508773792/customDimensions/14933188523` (`location`).
