# Step 4 — Pick the Beachhead

Choose ONE primary persona to build the entire strategy around. This is usually the hardest step — every choice feels like closing a door. That's the point. A beachhead is concentration.

**Mode:** Synthesis. Interview only to break ties.

**Artifact:** `marketing/04_beachhead.md`

## The concept

Geoffrey Moore's *Crossing the Chasm* (3rd ed., 2014): you don't win a market by being "for everyone." You dominate one tightly-defined segment, earn reference customers, then expand. Bill Aulet's *Disciplined Entrepreneurship* (2013) makes this explicit as Steps 2–4: Beachhead Market → End User Profile → TAM for Beachhead.

For a solo operator, this isn't optional. It's what makes the plan tractable.

## Moore's 9-point target-customer checklist

From *Crossing the Chasm*, Ch. 3. Rate each candidate persona High / Medium / Low on all nine:

| # | Criterion | Question |
|---|---|---|
| 1 | Target customer | Is there a single identifiable economic buyer? |
| 2 | Compelling reason to buy | Is the pain so acute the status quo is untenable? |
| 3 | Whole product | Can you assemble the full solution (with partners if needed) in a reasonable time? |
| 4 | Partners & allies | Are the needed partners already in place? |
| 5 | Distribution | Is there a channel motivated to sell/deliver it? |
| 6 | Pricing | Is pricing consistent with their budget and the value delivered? |
| 7 | Competition | Is the space defensible? |
| 8 | Positioning | Is the business credible here? |
| 9 | **Next target customer** | Does winning here create a domino into adjacent segments? |

Moore weights **#9 (the domino effect)** highest. Winning a beachhead that doesn't unlock anything adjacent is a dead end. Most founders miss this criterion.

## Additional criteria from other practitioners

Layer these on top:

- **Trigger frequency / urgency** (Moesta) — is there a recurring moment that forces the buyer to act? One-time triggers are weaker than recurring ones.
- **Existing alternatives** (Maurya) — what are they hiring today? Competitors prove budget exists; zero competitors often means zero market.
- **Maurya's 4-gate filter** — does this segment (a) have the problem, (b) know they have it, (c) actively look for a solution, (d) have budget? Fail any gate = drop.
- **Founder fit / unfair advantage** — does the user have credibility, network, or domain experience here? Unfair advantages compound; don't waste them.

## Criteria to demote or cut

- **Market size / TAM** — at beachhead stage this is mostly vanity. Aulet's rule: "big enough to matter, small enough to dominate" (~$20–100M TAM). Use as a **pass/fail floor**, not a score.
- **Competitive density (alone)** — double-edged. Zero competitors often = no market. Reframe as "is there evidence of budget / buying activity here?"

## Non-software / local / trades adjustments

Moore's list was written for software. Substitutions for physical/local businesses:

- **Geographic density** replaces TAM — can you service 80% of jobs within a 30-min drive?
- **Referral coefficient** replaces CAC — does this segment talk to each other? (Amplifies Aulet's word-of-mouth criterion.)
- **Repeat / recurring revenue potential** — trades are often one-shot; services can be retainers. Which is this segment?
- **Crew / capacity fit** — can your existing team deliver without hiring?
- **Permit / regulatory homogeneity** — one jurisdiction vs. many? Scattered regulations kill margins.

Drop "feedback loop speed" weighting for trades — one job takes weeks; don't penalize segments for physics.

## Scoring the candidates

For each persona from `marketing/03_personas.md`:

1. Score Moore's 9 criteria H/M/L.
2. Score the additional criteria (trigger frequency, Maurya 4-gate, founder fit).
3. Apply business-type adjustments.
4. Note any hard fails (e.g., Maurya gate fail = drop, not adjust).

Don't overthink the math. The *relative ranking* is what matters.

## Interview to break ties

If two personas score similarly:

> "Looking at these two — [A] and [B] — which one gets you excited? Which customers do you want to spend the next year talking to every day?"

Taste matters. A founder who dreads their customers won't sustain the work.

> "Which one do you have a real unfair advantage for? Network, past experience, credibility, existing audience?"

Unfair advantages compound. Use them.

## Graduation criterion — required

Every beachhead decision must include a **numeric graduation trigger**. Not a feeling — a specific threshold that says "we're ready to expand." Aulet's rule of thumb: ~20 paying customers in the beachhead with >50% penetration of the reachable sub-segment.

Template for software:
> "We graduate from [segment] when we have **20 paying customers** who (a) have renewed/repurchased, (b) given us at least one referral that closed, and (c) we can close new [segment] deals in under [X] days without founder involvement."

Template for local/trades:
> "We graduate when we have **10+ completed jobs** in the beachhead, **3 unsolicited referrals** from past customers, and a repeatable quote-to-close playbook that doesn't require the owner on every call."

Template for services/consulting:
> "We graduate when we have **5 retainer clients** in the beachhead, a waitlist, and one public case study per client."

Without a graduation criterion, founders switch beachheads every 90 days and never compound.

## Anti-patterns

- **"Boiling the ocean"** (Moore) — picking "SMBs" or "homeowners" — not a segment, a market
- **Founder-passion pick with no access** — Steve Blank's "get out of the building" exists for this
- **Beachhead ADD** (Aulet) — switching before hitting graduation criteria kills compounding
- **Picking by revenue-per-deal** — ignores sales cycle and reference value
- **Picking the segment that answers your calls** — responsiveness isn't fit, it's often just lonely buyers
- **"A and B" beachheads** — pick one. "We'll target both empty-nesters and contractors" = zero positioning clarity. Hold the line.

## Write the artifact

Write `marketing/04_beachhead.md`:

```markdown
# Beachhead — [Business name]

## Primary persona
**[Persona name from step 3]**

[One-paragraph description — who they are, the job they're hiring for, what triggered them to look.]

## Scoring

### Moore's 9-point checklist
| # | Criterion | Rating | Notes |
|---|---|---|---|
| 1 | Identifiable buyer | H/M/L | ... |
| 2 | Compelling reason to buy | H/M/L | ... |
| 3 | Whole product feasibility | H/M/L | ... |
| ... | ... | ... | ... |
| 9 | Domino / next-target unlock | H/M/L | ... |

### Additional criteria
- Trigger frequency: [H/M/L + note]
- Maurya 4-gate: [pass/fail per gate]
- Founder unfair advantage: [what it is, if any]

### Business-type adjustments
[If trades/local/services: geographic density, referral coefficient, repeat potential, crew fit, regulatory]

## Why this persona first
1. [reason — tied to the highest-scoring criteria]
2. [reason]
3. [reason]

## What we're deferring
- [Persona B] — deferred because [reason]. Revisit at [graduation trigger].
- [Persona C] — dropped. Research showed [reason].

## Graduation criterion
[Specific numeric trigger — see templates in step 4 doc]

## Risks of this choice
- [risk 1 — e.g., "narrow segment; if demand ceiling is lower than assumed, we hit it fast"]
- [risk 2]

## Risk mitigation
[What the user will watch for that would trigger reconsidering]
```

## Hand off to step 5

> "Locked in [persona] as the beachhead. Graduation trigger is [N]. Now I'll draft positioning — making clear to this persona why you're the right choice over the alternatives they're actually comparing you to."

Then load `steps/05_positioning.md`.
