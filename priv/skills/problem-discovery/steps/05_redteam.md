# Step 5 — Red-team

Prosecute each surviving Candidate (those that cleared the money gate with `score >= 3`) by writing a structural kill argument from the same evidence that promoted it. Produce a `RedTeamVerdict` that overwrites Score's verdict on the Board.

**Mode:** Per-Candidate conversational prosecution with the founder. One Candidate at a time. Not a batch operation.

**Output:** RedTeamVerdict per Candidate, replacing Score's mechanical KEEP/WATCH/KILL with a verdict prosecuted against the evidence.

**Theory grounding:** `research/05_red_teaming_candidates.md` (Klein pre-mortem, Munger inversion, Bezos Type 2), `research/06_pipeline_anti_patterns.md` anti-pattern 6 (services-vs-product split).

## The framing

You are NOT brainstorming risks. You are NOT writing a balanced "pros and cons." You are the devil's advocate in the Catholic tradition: **your job is to KILL the case** from the same evidence that supports it.

Use **past tense** (Gary Klein's prospective hindsight): not "what could go wrong?" but *"this bet has already failed 18 months from now. You invested. It didn't work. From the evidence you had at the time, what specifically went wrong?"*

The past-tense grammar activates specific recall instead of generic hedges. It produces "the third $40k client turned out to be the only real one; the rest were one-off enthusiasm" instead of "there might not be enough demand."

## The procedure (per Candidate)

For each Candidate with `score >= 3`, do this loop. **One at a time.** Do not red-team all candidates in a single batch — that defeats the conversational prosecution.

### 1. Load the evidence

> Call `ListPostingsForCandidate` with `{candidate_id: <id>}` to get each member JobPosting with its money signals + `classification`. Filter to `gated_in` client-side.

Read each posting carefully. Note:
- Total spend per client
- Hire rate per client
- Posting dates (recency)
- Whether one client is overrepresented
- The pain descriptors of the member JobPostings
- Anything that looks like an outlier or a coincidence

### 2. Construct the past-tense prosecution

To the founder:

> "Red-teaming Candidate [label]. Here's the setup:
>
> *It's 18 months from today. You decided this was the problem worth building for. You invested time and money. It didn't work — the product didn't find traction. Looking back at the evidence we had today, what's the single most damaging thing that explains the failure?*
>
> Here are the gated-in signals we have:
> - Client A: spent $X, hire rate Y%, hired N times for [description]
> - Client B: spent $X, hire rate Y%, hired N times for [description]
> - ...
>
> What's the kill argument?"

Let the founder propose a kill argument. The founder's domain knowledge produces the strongest arguments. If they're stuck, suggest one based on the evidence — but credit them for the better version.

### 3. Apply the four checks

The kill argument should hit at least one of these:

**a. Services demand ≠ product demand** (the biggest single failure mode, per anti-pattern 6)

Every gated_in signal is someone paying a *human specialist*. None of them prove anyone would pay for *software* that does the same thing. The split:

- **KEEP-PRODUCTIZABLE** — the work is repetitive, well-defined, low-judgment. A tool could plausibly substitute. (Migration scripts, data sync, automation.)
- **KEEP-SERVICE-ONLY** — the work requires human judgment, relationship navigation, or custom analysis. Software would not substitute. (Strategy consulting, organizational change management, custom integration design.)

Ask the founder explicitly: *"Could a tool do this work, or does it require human judgment a tool couldn't replace?"* If the answer is "requires human judgment," this Candidate downgrades to WATCH or KILL-SERVICE-ONLY regardless of money signal strength.

**b. Loud minority / concentration**

Is the signal driven by one whale client posting repeatedly? 6 gated_in signals from 1 client = 1 data point with multiplicity, not 6. Look at distinct-client count. If `distinct_clients < 3`, the demand is concentrated, not broad. Verdict downgrades.

**c. Wrong-domain spend**

Upwork's `total_spent` is the client's lifetime spend on *Upwork in general*, not on this specific problem. A client with $400k lifetime spend who hired for one job in this domain might be a serial Upwork buyer trying something new, not a demonstrated buyer of this specific work. Check whether the client's other Upwork jobs (if visible) are in the same domain.

**d. Pain is solved adequately by adjacent existing tools**

If the founder builds a tool for this and the existing market already has 2-3 mediocre tools that 80% solve the pain, the rational client choice is "stick with adequate" rather than "switch to your new thing." The kill argument here: "There's already X and Y that do most of this — why would these clients switch?"

### 4. Write the verdict

After the kill argument is constructed, the verdict is one of:

- **KEEP-PRODUCTIZABLE** — money signal is strong, distinct clients ≥ 3, kill argument is survivable, work is productizable
- **KEEP-SERVICE-ONLY** — money signal is strong, kill argument survives EXCEPT services-vs-product fails (this is a great services lead, not a product lead)
- **WATCH** — signal is real but concentrated, recent, or the kill argument is partially damaging — needs more data before committing
- **KILL** — kill argument is survivable for the founder, meaning they can't credibly answer it from the evidence

For the cheapest-kill-test: ask *"what's the single cheapest experiment that would confirm or kill this kill_argument before any code gets written?"* A 30-minute phone call with one of the gated_in clients usually beats anything else. A landing-page test, an outreach email with a price tag, an offer to do the work manually for a fee — all candidates.

### 5. Persist the verdict

> Call `RedTeamCandidate` with `{candidate_id: <id>, verdict: :keep_productizable | :keep_service_only | :watch | :kill, kill_argument: "...", cheapest_kill_test: "..."}`.

This overwrites Score's mechanical verdict on the Board. The RedTeamVerdict is what the founder sees and acts on.

### 6. Repeat per remaining Candidate

Continue per-Candidate. Don't batch. The founder is in the loop on each one because their judgment is what makes the prosecution honest.

## Watch for these failure modes

- **Balanced report** — the devil's advocate is not balanced. "On one hand X, on the other hand Y" is brainstorming, not prosecution. The kill argument should be the *strongest single damaging interpretation* of the evidence.
- **Generic hedges** — "demand might not be sustainable" is not a kill argument; "the three biggest spenders all hired in Q1 2024 and haven't posted since — this could be a 2024 trend that's already over" is.
- **Conflating money signal with product demand** (anti-pattern 6) — the single biggest failure mode. Every Red-team must explicitly address services-vs-product or it's not a real prosecution.
- **Skipping Red-team on "obvious" Candidates** — if a Candidate looks like a slam-dunk, that's exactly when the kill argument matters most. Survivorship of an obvious thesis is the strongest signal; unprosecuted obvious thesis is the weakest.

## Hand off to step 6

> "Red-team is done. Each surviving Candidate has a prosecuted verdict, a kill argument, and a cheapest-kill-test. Now I assemble the Board — the founder can scan it row by row and kill anything in one click."

Then load `steps/06_board.md`.
