# `stage_response` synopsis is write-once on Thread; placeholder values stick

Filed 2026-05-22 from MMS MCP usage during the CodeMySpec marketing cycle.

## Problem

`stage_response` writes the `synopsis` field onto the parent Thread. The current behavior: write-once, no overwrite. If the first call passes a placeholder ("test", "stub", "short synopsis"), that value sticks permanently, even when subsequent calls pass the real synopsis.

Hit this multiple times in a single session today as a workaround for the now-fixed synopsis length cap (filed separately, since resolved): pass `synopsis: "stub"` to get the touchpoint created, then try to update the real synopsis on a follow-up call. The follow-up silently no-ops on the synopsis field.

**Failure mode:** the operator loses real synthesis work to a placeholder, and there's no error or warning indicating the overwrite was suppressed.

## Acceptance criteria

Choose one:

1. **Allow overwrite** — `stage_response` always writes the current `synopsis` to the Thread, regardless of prior value. Simplest. Trade-off: a misfire could clobber a real synopsis.

2. **Hard-error on overwrite attempt** — if Thread.synopsis is non-empty and a new value is passed, return a clear error like `synopsis_already_set: existing synopsis is "..." — pass overwrite: true to replace`. Forces explicit intent.

3. **Add an `overwrite` boolean parameter** — defaults to false (current behavior). When true, replaces. Compatible with existing callers.

Recommend option 3 — preserves the write-once safety for typical use, gives an escape hatch when needed, and the error message tells the caller exactly how to opt in.

## Test surface

- `stage_response` MCP tool tests in MMS server
- Whatever fixture/spex covers the Thread.synopsis write path

## Reference

- Caller-side documentation of the issue: `code_my_spec_marketing/marketing/daily/2026-05-22.md` (MMS gap #2)
