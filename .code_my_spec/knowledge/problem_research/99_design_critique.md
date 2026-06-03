# Design Critique: The 5-Stage Pipeline Against Practitioner Literature

## Scope

This critique stacks the `discover(problem) → Board` pipeline (Frame → Gather →
Cluster → Score → Red-team) against the body of knowledge in files 01–06. It
distinguishes what is well-grounded, what is novel and untested, and what is
underspecified. It names the stage, the move, and the source for every claim.

---

## What is well-grounded

### Money gate design (Score stage)

The `totalSpent × hireRate` gate is the strongest design decision in the pipeline. It
implements the Fitzpatrick / Hoy hierarchy correctly: observed economic behavior (actual
payments) over stated intent (posted budget). The distinction between `strong`, `thin`,
`noise`, and `unknown` tiers maps to the practitioner hierarchy almost exactly. Using
`hireRate` as a tire-kicker filter is not in the literature — it is a genuine empirical
insight from the bakeoff that practitioners should adopt.

**Source alignment:** Fitzpatrick ("people stop lying when you ask for money"),
Hoy ("observing lions in a zoo"), patio11 (demonstrated spend > stated intent).

### LLM as volume labeler, human as gate (relevance axis)

The pipeline's architecture — LLM judges relevance, human tunes thresholds, money is
the hard gate — correctly separates machine work from judgment work. The LLM is not the
source of truth; it handles scale. This is the correct division of labor per the
grounded-theory and card-sorting literature: machines are good at applying a human-
defined schema at scale, bad at inventing valid schemas from scratch.

**Source alignment:** Grounded theory (categories from data, not from the model);
card-sorting bias research (LLM card sorting shows "lack of realistic diversity").

### Red-team as structural prosecution (Red-team stage)

The README's "per KEEP, LLM argues against it from the same evidence" is exactly the
Klein pre-mortem and Munger inversion pattern. The design correctly separates the
prosecution pass from the scoring pass rather than asking the scoring logic to be both
judge and devil's advocate.

**Source alignment:** Klein (prospective hindsight), Munger (inversion interrupts
first-conclusion bias).

### Kill argument as first-class field (Board output)

Surfacing `kill_argument` at the same level as `money_tier` and `relevance` in the
Board output is the right UX decision. It prevents the board from becoming an
affirmation artifact.

---

## What is novel and untested

### `totalSpent × hireRate` as money gate

This combination is not in any published validation methodology. The literature's money
signals are: (1) did you get a credit card? (2) did they sign an LOI? (3) did they
show up to a meeting? None of them use marketplace behavioral stats as a proxy. The
pipeline's insight — that a client's posting behavior is a better signal than their
stated budget — is novel and plausible but not validated by independent research. It
could be wrong in edge cases (e.g., a client with high spend and high hire rate in an
unrelated domain who is exploring a new problem).

**Risk:** The money gate is a proxy for willingness to pay for _this specific problem_.
It is actually willingness to pay on _Upwork in general_. A client who has spent $400k
on Upwork is a proven buyer — but of Upwork labor generally, not of CRM migration
specifically. The relevance axis is supposed to correct for this, but the correction is
imperfect.

**Mitigation:** The score stage could add a "spend recency" filter — did the client's
spend occur in the relevant domain (check their other posted jobs)? This is not
currently implemented.

### LLM red-teaming as a substitute for a human devil's advocate

Using an LLM to argue against its own evidence is novel. The Catholic and Kleinian
traditions both require a human who is explicitly adversarial because humans have ego
invested in the verdict. An LLM has no ego investment and therefore can "argue against"
without the social friction that makes pre-mortems valuable. Whether LLM prosecution
produces the same quality of kill arguments as human devil's advocates is untested.

**Risk:** The model may produce kill arguments that are technically adversarial but
miss the specific failure mode a domain expert would name immediately.

---

## What is underspecified

### Frame stage — no kill condition or calibration set requirement

**Stage:** Frame
**Problem:** The pipeline has no explicit "what would make this a NO before we gather"
field. The opportunity_brief.md has a kill condition retrospectively, but it was not
written before the data run.
**Fix:** Add two required fields to the Frame artifact:
  - `kill_condition: "Fewer than N money-gated rows across M framings → NO"`
  - `calibration_n: "Read these N records before running LLM relevance; encode
    your own KEEP/KILL verdicts as the calibration set"`
**Source:** Blank (falsifiable hypotheses have kill conditions); grounded theory
(calibration before automated coding).

### Cluster stage — not yet built

**Stage:** Cluster
**Problem:** The Cluster stage is listed in the README but absent from the codebase.
When built, the wrong implementation (give me 5 categories for these 200 records) will
produce the "confident but wrong taxonomy" the intent doc warns against.
**Fix:** Implement the three-pass grounded-theory structure: describe (pain per record),
group (affinity on pain descriptors), name (labels emerge from groups). Prompt
separately for each pass. Require a calibration-set comparison before accepting the
taxonomy.
**Source:** Grounded theory open/axial/selective coding; KJ method (name after group).

### Signal class metadata — no adapter-level tagging

**Stage:** Gather, Score
**Problem:** All records are treated as if they carry the same type of evidence.
An Upwork record with `totalSpent` and a Reddit post with "looking for someone to do
X" should not feed the same scoring logic.
**Fix:** Add `signal_class: "marketplace_with_stats" | "marketplace_no_stats" |
"job_board" | "community_pain" | "review_site"` to `NormalizedRecord`. The Score stage
applies the money gate only to `marketplace_with_stats`. Others max out at `WATCH`.
**Source:** Signal class hierarchy in `03_marketplace_signal_extraction.md`.

### Red-team — no "cheapest next test" field

**Stage:** Red-team, Board
**Problem:** The Red-team stage generates a kill argument but not an actionable next
step. The Board shows KEEP/WATCH/KILL but not "and here is the one thing that would
resolve this."
**Fix:** Add `cheapest_kill_test: str` to the Board row. Prompt: "What is the
lowest-cost experiment that would confirm or falsify the kill argument above?"
**Source:** Bezos (Type 2 decisions — reversible, identify the cheapest test);
Fitzpatrick (what commitment would you ask for next?).

### Corpus health — no validation theater guard

**Stage:** Board output
**Problem:** A Board with 3 KEEP rows from a 20-record corpus looks like strong
validation. It is not.
**Fix:** Add a corpus health block to the Board header:
  - Total records / records with client stats / records clearing money gate /
    distinct clients in KEEP tier
  - Threshold warning: if `distinct_keep_clients < 5` or `total_records < 50`,
    display "THIN CORPUS — treat all verdicts as Frame input, not validation."
**Source:** Anti-pattern 5 (validation theater); Walling (n=17 was too small for Drip
without pre-sales commitment).

### Services vs. product demand — no explicit split

**Stage:** Red-team, Board
**Problem:** Every Upwork record proves services demand. None prove product demand.
The KEEP category currently makes no distinction.
**Fix:** Add `demand_type: "services" | "product" | "unknown"` to Board rows, populated
by the Red-team stage. Prompt: "Based on the job description, is the client seeking a
human specialist (services) or a tool/automation (product)? If human specialist, could
a software tool plausibly substitute?" Rows that are `services` without clear product
substitution potential become `WATCH` regardless of money strength.
**Source:** Opportunity brief §1 ("services demand ≠ product demand"); Fitzpatrick
(money commitment ≠ money for _your_ product).

---

## Summary verdict

The pipeline's core architecture is sound and grounded in practitioner thinking. Its
money gate is more sophisticated than anything in the published validation literature.
Its LLM-as-volume-worker architecture is correctly designed.

The three structural additions that would most strengthen it:

1. **Frame: kill condition + calibration set** — prevents the pipeline from running
   against an unfalsifiable hypothesis.

2. **Cluster: grounded-theory three-pass structure** — prevents the most dangerous
   failure mode the intent doc names (confident taxonomy, wrong categories).

3. **Board: KEEP split into productizable vs. services-only** — closes the single
   biggest gap between "promising discovery output" and "validated business case."
