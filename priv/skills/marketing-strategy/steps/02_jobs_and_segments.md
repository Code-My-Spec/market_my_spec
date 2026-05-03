# Step 2 — Jobs-to-be-Done and Segments

Interview the user about the *job* customers hire the product/service for, and sketch 2–4 hypothesized segments. The output of this step is what research agents validate in step 3.

**Mode:** Interview. No external research yet.

**Artifact:** `marketing/02_jobs_and_segments.md`

## Why this step before research

Research agents need seed personas to go validate. "Research customers of a countertop installer" returns a generic report. "Research homeowners aged 45–65 doing full kitchen remodels in Tampa, anchored around the empty-nest life event" returns specifics. Your job in step 2 is producing the latter.

## Framework — Moesta's Switch Interview (adapted for founders)

Bob Moesta and Chris Spiek's Switch Interview (from *Demand-Side Sales 101*, 2020, and ReWired Group workshops) is the practitioner JTBD method. It anchors on a *specific recent purchase* and walks backward from purchase moment to first thought, surfacing the four Forces of Progress: Push (pain of current state), Pull (attraction of new state), Anxiety (fear of switching), Habit (inertia).

**Standard Moesta questions** (for customer interviews):

1. When did you *first* realize you needed something like this?
2. Where were you? What was going on in your life?
3. What were you using before? Why wasn't it working anymore?
4. What finally pushed you to make the switch?
5. Who else was involved in the decision?
6. What almost stopped you from buying?
7. What did you imagine your life would look like after?
8. If you couldn't have this, what would you do instead?

Structural rules: anchor on a specific purchase episode, never ask "why" (ask "what happened"), walk the timeline backward.

## Founder-as-proxy adaptation

You're interviewing the founder, not the customer. The founder is reporting second-hand. Adjustments:

- **Force specific named customers, not archetypes.**
  > "Tell me about the last 3 people who bought. Walk me through each one by name."
- **Episode, not pattern.**
  > "What did Sarah say in the sales call? What were her exact words?"
- **Flag inference vs. evidence.**
  > "Is that what she told you, or what you think she meant?"
- **Ask for the alternative.**
  > "What was she doing before she called you?"
- **Include lost deals and churn.**
  > "Tell me about someone who almost bought but didn't. And anyone who left after buying."

If the founder has zero customers, skip to the hypothesis segment section.

## The job-to-be-done — functional, emotional, social

> "When someone hires you, what are they actually trying to accomplish? Not the deliverable — the outcome in their life or business."

Good JTBD framing:
- Granite countertops: "Make my kitchen feel like the finished, grown-up home I thought I'd have by this stage" — not "install stone"
- Business consultant: "Help me look competent to my board at the next meeting" — not "write a strategy doc"
- Dev tool: "Ship this feature before the end of the quarter without burning my weekend" — not "generate code"

The functional job is usually obvious. Push for the **emotional** and **social** job underneath.

### Optional: Ulwick outcome statements

For precision, Tony Ulwick's Outcome-Driven Innovation (*Jobs to be Done: Theory to Practice*, 2016) formats desired outcomes as:

> [direction] + [metric] + [object of control] + [contextual clarifier]

Example: "Minimize the time it takes to determine whether a countertop seam will be visible after install." These are useful when you need to test claims or write benchmarks. Skip for non-software unless the user is naturally analytical.

## Hypothesized segments

Based on the interview, propose 2–4 candidate segments. Differentiate them on something that matters for marketing — **trigger event first**, then firmographic/situational context, then demographics as a last resort.

**Segmentation priority order** (when you have <20 customers):

1. **Trigger event** — the moment that makes someone start looking ("failed DIY tile job," "kid left for college," "lost a case in court")
2. **Willingness-to-pay behavior** — who paid fastest, at full price, with least friction
3. **Firmographic / situational** — company size, home value, project stage, practice type
4. **Demographic** — age, role — only when it correlates with a job. "Marketing Mary, 42" without a trigger is useless.

Example — candidate segments for a granite countertop business:

- **Empty-nester full remodels** — 45–65, kids just gone, $800K+ home, trigger = "time to finally fix up the house"
- **New-home flippers** — investor buying mid-tier homes, upgrading kitchens to sell, trigger = deal closing
- **Contractor pass-through** — GCs on new builds who need a reliable stone sub, trigger = new project kickoff

## Handoff readiness test

Before step 3, each segment must pass this checklist. If it fails, keep interviewing or drop the segment.

| Check | Question |
|---|---|
| Trigger named | What event specifically makes this person start looking this week/month? |
| Current alternative identified | What are they hiring today (including "nothing")? |
| Struggling moment in one sentence | Can you describe the concrete moment of frustration? |
| Reachable identifier | Where do they show up — subreddit, forum, trade show, Google query, Houzz tag, referral source? |
| At least one named real example | Can the founder point to one real person (or close proxy) who fits? |

A segment that fails any of these is too fuzzy to research productively.

## Write the artifact

Write `marketing/02_jobs_and_segments.md`:

```markdown
# Jobs and Segments — [Business name]

## Functional job
[What customers are literally trying to get done]

## Emotional job
[How they want to feel]

## Social job
[How they want to be perceived]

## Switch interview notes (if available)
For each named customer the founder discussed:
- Name / identifier
- Trigger event (what happened right before they started looking)
- What they were doing before (previous alternative)
- What pushed them to switch
- What almost stopped them (anxieties)
- What they imagined would be different after

## Candidate segments

### Segment A: [short memorable name]
- **Profile:** [role / demographic / situational context]
- **Trigger event:** [specific moment]
- **Current alternative:** [what they're doing today]
- **Struggling moment:** [one-sentence concrete pain]
- **Reachable identifier:** [where they show up]
- **Named example:** [one real person/org, or "hypothesis only"]
- **Handoff readiness:** [pass / fail]

### Segment B / C: [same structure]

## Dropped segments
[Any candidate that failed the readiness test, with the specific check that failed]

## Open questions for step 3 research
- Is Segment A actually reachable in volume? Where specifically?
- What alternatives do they use most often?
- What vocabulary do they use for the problem?
- What are the real pains, in their own words?
- Any disconfirming evidence — is this segment a mirage?
```

## Hand off to step 3

> "Good — [N] segments ready for research. Next I'll dispatch agents to validate these: where they actually hang out, what language they use, and what they're doing today instead of hiring you."

Then load `steps/03_persona_research.md`.
