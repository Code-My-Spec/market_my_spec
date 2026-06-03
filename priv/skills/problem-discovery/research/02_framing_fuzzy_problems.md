# Framing Fuzzy Problems

## Executive summary

A fuzzy hunch becomes a researchable hypothesis when you specify the customer segment,
the context triggering the pain, and the measurable outcome that would prove the pain
exists. The move from "I think there's a market for X" to "here is the Y/N question my
evidence will answer" requires three ingredients: a forcing structure, a vocabulary
audit, and a kill condition written before you start.

---

## Canonical sources

### Steve Blank — Customer Development / The Startup Owner's Manual (2012)

Blank's contribution is turning the business model into a set of _falsifiable_
hypotheses. Every assumption about customer segment, problem severity, and willingness
to pay is written as a testable statement before any data collection. The key
discipline: hypotheses must be structured so that specific evidence can kill them, not
just confirm them. The hypothesis "SMBs have CRM migration pain" is unfalsifiable; the
hypothesis "SMB owners who have migrated a CRM in the past 12 months rated it 7+/10
difficulty AND said they'd pay to speed it up" is falsifiable.

Blank's four-stage Customer Development model (Discover → Validate → Create → Build)
insists you leave the building with specific questions, not a pitch. The Frame stage
in our pipeline is the equivalent of his "hypothesize" step.

Source: _The Startup Owner's Manual_, Blank & Dorf, 2012.
https://steveblank.com/tag/customer-discovery/

### Bob Moesta — Jobs to Be Done switch interview (2016–present)

Moesta's JTBD reframe: don't start with "what is the problem?" Start with "what
event caused the switch?" The four forces of progress — Push (frustration with old
solution), Pull (attraction of new solution), Anxiety (fear of switching), Habit
(inertia) — create a richer hypothesis than a pain statement alone. For the pipeline,
this means the Frame query should capture the triggering context ("migrating to
GoHighLevel") not just the domain ("CRM migration"), because the switch event is what
separates latent pain from active demand.

The critical framing move: "I have no hypothesis. I know the switch happened. I'm
mapping backward from the purchase moment." This prevents leading the data.

Source: Intercom podcast with Moesta, 2016.
https://www.intercom.com/blog/podcasts/bob-moesta-on-unpacking-customer-motivations-with-jobs-to-be-done/

### Rob Fitzpatrick — The Mom Test, problem interview structure (2013)

Fitzpatrick's framing rule: before any research, write down the three things you most
want to prove are true. Then design questions (or in our case, queries) that could
disprove them. If your Frame stage produces a query string that only finds confirming
evidence, it's not a hypothesis — it's a wishlist.

His specific move for "fuzzy to testable": replace "do you have a problem with X" with
"walk me through the last time you tried to do X." Translated to the pipeline: the
Frame query string should anchor on the last action (e.g., "migrating sub-accounts")
not the desired solution.

Source: _The Mom Test_, 2013. https://www.momtestbook.com/

### Sean Murphy — Phoenix Checklist for framing (2019)

Murphy's Phoenix Checklist (adapted from the CIA's original) asks 15 questions to
structure a problem statement before committing to research. The ones that matter most
for the Frame stage:
- "Why is it necessary to solve the problem?"
- "What assumptions have you made?"
- "How certain are you of each piece of information?"
- "What would you do if you could not solve this problem?"

The last question is the kill-condition test: if the answer is "nothing changes," the
problem is not severe enough to gate on.

Source: "The Phoenix Checklist for Framing a Problem and Its Solution," Sean Murphy,
2019. https://www.skmurphy.com/blog/2019/08/10/the-phoenix-checklist-for-framing-a-problem-and-its-solution/

---

## Mapping to the 5-stage pipeline

**Frame stage (directly)**

The Frame artifact should answer these questions before the Gather stage runs:
1. Who is the customer segment? (Blank: be specific enough to falsify)
2. What triggering event activates the pain? (Moesta: switch context, not domain)
3. What vocabulary does the market use? (Hoy: use their words, not yours)
4. What result would make this a NO? (Fitzpatrick: write the kill condition first)
5. What is the narrowest query that captures the switch event? (not "CRM migration"
   but "GoHighLevel agency sub-account migration")

The `framings_migration.txt` file in the broken_oaths repo is already doing this
empirically — multiple framings of the same problem. That's correct methodology.

**Score stage (relevance axis)**

The relevance prompt (`RELEVANCE_SYSTEM` in `discover_score.py`) is already doing
Blank's falsification: it's asking "is this actually about the problem?" not "does
this confirm the problem exists?" The LLM judge needs the same precision vocabulary
that the Frame stage should produce.

---

## Where our intent doc is silent / contradictory

- The pipeline has no explicit "kill condition" field in the Frame artifact. The
  opportunity_brief.md has it implicitly ("worth one more validation sprint, not worth
  building yet") but that's post-hoc. The Frame stage should require stating upfront:
  "If fewer than N money-gated rows appear across M framings, this is a NO."

- Moesta's switch-event framing is not in the pipeline. The current Frame is
  domain-vocabulary-driven. Adding a "what is the triggering event?" field to the
  Frame artifact would improve Gather recall — job postings describing the switch event
  are often the highest-value rows.
