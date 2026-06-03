# Red-Teaming and Steelmanning KEEP Candidates

## Executive summary

Red-teaming is not brainstorming — it is a structured prosecution of your own
conclusion using the same evidence that produced it. The canonical structure: state the
verdict, argue from evidence that it is wrong, write the strongest possible kill
argument, and only move to the Board if the kill argument fails. The pipeline's
"every row is built to be killed by one click" principle is exactly right; it needs a
formal procedure.

---

## Canonical sources

### Gary Klein — Pre-mortem / Prospective Hindsight (HBR, 2007)

Klein's contribution: the grammatical shift from "what could go wrong?" (conditional,
suppresses dissent) to "it has already failed — what went wrong?" (past tense,
activates specific recall). This is "prospective hindsight" and improves risk
identification by ~30% in controlled studies (Wharton, Colorado, Cornell, 1989).

For the pipeline: the Red-team stage prompt should not say "what might make this a bad
opportunity?" It should say: "This bet has already failed 18 months from now. You
invested, and it didn't work. Here is the evidence that existed at evaluation time
[insert the KEEP row]. What specifically went wrong?"

Source: Klein, "Performing a Project Premortem," _Harvard Business Review_, 2007.
https://hbr.org/2007/09/performing-a-project-premortem

### Charlie Munger — Inversion (Berkshire Hathaway letters, Poor Charlie's Almanack)

"Invert, always invert." Munger's framing: most problems can't be solved forward; many
can be solved by mapping the path to the worst outcome and then not taking it. Applied
to problem validation: instead of "why will this succeed?" ask "how could this row be
a false positive?" The inversion forces specific mechanisms of failure rather than
general hedges.

Munger's specific move: "first-conclusion bias" — the automatic tendency to seek
evidence that confirms the first conclusion. Inversion interrupts this. The Red-team
stage must explicitly argue _against_ the verdict, not just note hedges.

Source: Farnam Street, "Inversion: The Power of Avoiding Stupidity," 2021.
https://fs.blog/inversion/

### The Devil's Advocate structural role

Historically used by the Catholic Church's Congregation of Rites (beatification
process) — a formally designated role whose job is to argue against canonization using
the same evidence that supports it. The key structural feature: the devil's advocate
is not trying to be balanced or fair; they are trying to kill the case. The result is
not a "both sides" report — it is the strongest possible kill argument, then a
deliberate decision about whether that argument is survivable.

For the pipeline: the Red-team LLM prompt should be explicitly adversarial, not
balanced. "You are arguing this is a bad bet. Use only the evidence in this record.
What is the most damaging interpretation?"

### Jeff Bezos — Disagree and Commit / "Is this a one-way door?"

Bezos's two-door framework distinguishes Type 1 decisions (irreversible, require
deep analysis, survive the red-team) from Type 2 decisions (reversible, proceed
with less analysis). The Board output is a Type 2 decision for each row — KEEP/WATCH
means "run the next experiment," not "build the product." The Red-team stage should
make the reversibility explicit: "What is the cheapest test that would confirm or kill
this row's kill argument?"

Source: Bezos 2016 Amazon Annual Letter.

---

## Mapping to the 5-stage pipeline

**Red-team stage (directly)**

The README lists Red-team as "per KEEP, LLM argues against it from the same evidence."
That is the correct design. The specific prompt structure, grounded in the above:

```
CONTEXT: This row scored KEEP based on the following evidence:
  - Client spent: $[X] | hire rate: [Y]%
  - Job title: [...]
  - Description excerpt: [...]

TASK: You have already invested in building this. 18 months later it failed.
Argue from ONLY this evidence — no outside assumptions — for the single most
damaging reason it was a false positive.

Finish with: "The cheapest test that would have killed this before building: [test]."
```

This prompt structure combines Klein's prospective hindsight, Munger's inversion, and
Bezos's reversibility test.

**Score stage — kill_argument field**

The `kill_argument` field in `discover_score.py` is the seed of the Red-team stage.
Currently it is populated automatically by the verdict logic (e.g., "single posting —
could be one-off"). The Red-team stage should take those auto-generated kill arguments
and either confirm them with a deeper LLM pass or replace them with a stronger one.

**Board output**

Each KEEP row on the Board should display its kill argument with equal prominence to
its money signal. The current scored_board.json does this (kill_argument is a top-
level field). The UI layer (the Board) must not bury it.

---

## Where our intent doc is silent / contradictory

- The pipeline names Red-team as a stage but does not specify whether it is a separate
  pass or happens inline with scoring. Klein's pre-mortem requires a separate,
  deliberate step (not a concurrent one) because inline hedging tends toward
  "on the other hand" balance rather than adversarial prosecution.

- There is no "cheapest next test" field in the Board output. Adding one would make the
  Board actionable rather than informational — the Red-team stage's kill argument
  implies what kind of evidence would resolve it.
