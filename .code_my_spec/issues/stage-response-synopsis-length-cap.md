# `stage_response` synopsis silently caps at ~200 chars; longer inputs fail with opaque `Invalid params`

Filed 2026-05-22 (regression verification). The operator was told this was fixed earlier today; today's verification call confirms it still reproduces.

## Problem

`stage_response` accepts a `synopsis` argument with a maxLength documented at 4000 chars in the MCP schema:

```
"synopsis": {"maxLength": 4000, "type": "string"}
```

In practice, synopses longer than ~200 chars cause the MCP call to fail with:

```
MCP error -32602: Invalid params
```

No further detail, no field-level error, no indication that synopsis specifically is the offending field.

## Reproduction

Today's verification (2026-05-22):

- Synopsis of 700 chars → fails with `MCP error -32602: Invalid params`
- Synopsis of 160 chars → succeeds, touchpoint created

Same boundary as observed on 2026-05-21 in the prior session. Today the operator confirmed the issue was supposed to be fixed; verification call reproduces the failure mode unchanged.

## Why it matters

1. **Operator loses synthesis work.** The natural use of synopsis is a 2-3 sentence read of the parent thread (top comments, OP's framing, room state). That's typically 300-800 chars. Operators hit the cap on first real use, get an opaque error, then have to truncate-and-retry, often losing the bit they care about.
2. **Schema lies.** `maxLength: 4000` in the schema is at least 20x what actually works. Callers trust the schema.
3. **Error message is unactionable.** `Invalid params` with no field hint forces operators to bisect — guess which field, halve the length, retry, repeat. Even after diagnosing, every future occurrence requires re-remembering.

## Acceptance criteria

1. **Find the actual enforced limit.** If it's intentional (e.g., DB column constraint), document it. If it's a Peri/Ecto validator, fix it to match the documented 4000 or update the schema to match reality.
2. **Return a clear validation error.** Replace the generic `Invalid params` with something like `{:error, :synopsis_too_long, max: N, got: M}` so the caller knows exactly what failed and how to fix it.
3. **Add a regression test** asserting that `stage_response` with a synopsis at the documented `maxLength` succeeds.
4. **Update the workaround memory in the operator's caller skill** — current workaround is "stub + update_touchpoint to set the real angle", which also loses the real synopsis to the Thread.synopsis write-once rule (filed separately as `synopsis-write-once-stickiness`). The two issues compound: short synopsis sticks forever, can't be overwritten with the real thing later.

## History

- 2026-05-21: First observed during MMS cycle stages 1+2 work on prod. Hit ~3 times before workaround established (stub + update_touchpoint).
- 2026-05-22 morning: Operator said the issue had been fixed. Issue file was not initially filed for this reason.
- 2026-05-22 afternoon: Re-tested with a 700-char synopsis on touchpoint `37bc0a06-cdd3-46f5-a08e-d56dc604f829` (r/ClaudeAI thread 1tjzqrx). Same `Invalid params` error. Issue reopened and filed.

## Out of scope

- Synopsis content / structure validation. The cap is the bug; what goes in the synopsis is the operator's call.
- Touchpoint `polished_body` length limits — separate path, separate test surface.

## Reference

- Caller-side: `code_my_spec_marketing/marketing/daily/2026-05-22.md` (MMS gap log).
- Related: `synopsis-write-once-stickiness.md` (compounding effect — short synopsis sticks because Thread.synopsis is write-once).
