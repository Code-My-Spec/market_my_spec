# Step 1 — Current State

Capture what the business is, who the founder/operator *thinks* it's for, and what they've tried. This is the baseline. Later steps will challenge these assumptions.

**Mode:** Interview only. No research yet.

**Artifact:** `marketing/01_current_state.md`

## Before asking

Fetch what's publicly visible first. Don't ask the user to type things the web already answers.

- Website (WebFetch)
- Google Business Profile for local businesses (search "[name] [city]")
- Yelp / Angi / Houzz / Zillow / LinkedIn / GitHub / Product Hunt — whatever fits the category
- Any social profile the user mentions

Pull what they sell, who they claim to serve, and what proof they show.

## Interview principles

- **Ask about past behavior, not future intent or opinion.** Rob Fitzpatrick, *The Mom Test* — this is the single highest-leverage rule in early interviews.
- **One or two questions at a time.** Pace yourself. React before asking the next.
- **Specific > abstract.** Push back on "small businesses" or "homeowners." Demand a name, a role, a context.
- **Appetite + no-gos are load-bearing.** Ryan Singer's Shape Up frame — knowing what the user *won't* do shapes the plan as much as what they will.

## The interview

### 1. Business in plain words
> "In one or two sentences, how would you describe what you do to someone in your industry?"

Compare to what the website/listing says. Gaps between spoken and public-facing descriptions are the first positioning signal.

### 2. Origin
> "What got you started? What were you seeing that made you think this was worth doing?"

The origin insight often contains a sharper ICP clue than they realize.

### 3. Stage and appetite
> "Where are you today — pre-revenue, first paying customers, steady flow, or stalled?"
> "What's the appetite for this problem — a quarter of effort, a year, or bet-the-company?"

Branches the rest of the flow. (Appetite framing from Shape Up.)

### 4. Past behavior — the last 3 customers
> "Walk me through the last three customers you closed. How did each one find you, and what did they say right before they bought?"

This is the single most valuable question in the whole interview. The Mom Test principle: past behavior beats future intent. Real customer language beats founder summary. If they can't name three recent customers, that's itself a signal (often points to PMF, not marketing — see red flags below).

### 5. What's actually working
> "If you stopped all marketing tomorrow, where would the next customer still come from?"

Surfaces the *real* working channel vs. theater. Be skeptical of "word of mouth" — probe for the actual referral path. Who told them? Where did the conversation happen?

### 6. What they've tried and why it failed
> "What have you tried that didn't work, and why do you think it failed?"

Prevents you re-prescribing it. Capture tried → result → their theory of why.

### 7. Existing alternatives (including "do nothing")
> "What are customers doing instead of hiring you today? Include 'nothing at all' and 'an intern / spreadsheet / DIY.'"

Lean Canvas (Ash Maurya): the existing alternatives (including status quo) are the real competition. Most founders skip "do nothing" — it's often the #1 competitor.

### 8. Constraints and no-gos
> "Realistically, how much time per week can you spend on marketing? Any budget? Anything you flat-out won't do — channels, tones, customers you'd turn down?"

Respect these downstream. A strategy that requires things the user won't do is theater. Common hard nos:
- "I hate being on camera"
- "No paid ads"
- "No weekends"
- "I have 3 hours a week, that's it"

### 9. 90-day success
> "What does revenue, leads, or milestones need to look like in 90 days for this to have been worth it?"

Concrete calibration for step 8's goal-setting.

## Red flags — signs the real problem isn't marketing

Listen for these during the interview. If you hear them, say so out loud:

- **Can't name 3 recent customers or cite a single verbatim quote** → likely PMF, not marketing
- **"Everyone needs this"** or no answer on existing alternatives → segment undefined
- **High churn, low repeat-purchase, or refunds** → fix retention before acquisition (Andrew Chen, "The Law of Shitty Clickthroughs")
- **Closes in person but nothing converts online** → messaging problem, not channel problem
- **Tried 6 channels for 2 weeks each, all "didn't work"** → execution/patience problem; marketing takes longer to compound than founders expect

Name the red flag in the artifact. Don't silently proceed — the user needs to know the strategy can't fix a PMF or retention problem.

## Business-type adaptations

Most of the interview is universal. Adjust these:

- **Local / trades (e.g. countertops, roofing, home services):** Add "What's your service radius and job-size floor?", "Referral vs. Google vs. repeat — current mix?", and "Who else gets called for this job — GC, designer, plumber?" (adjacency referral partners).
- **Consulting / professional services:** Add "What's the smallest engagement you'll take, and the biggest you've delivered?" — sizes the offer ladder.
- **Software / SaaS:** Add "What's the activation path — what has to happen in the first session for a user to stick?" Useful if you later discover retention is the bottleneck.

## Write the artifact

Write `marketing/01_current_state.md`:

```markdown
# Current State — [Business name]

## What they do
[1-2 sentences from the founder, in their words]

## Origin
[What prompted them to start]

## Stage + appetite
[Pre-revenue / early / steady / stalled — and how much they're willing to invest in solving this]

## Public-facing description
- **From website/GBP/etc:** "[quote]"
- **Proof shown:** [testimonials, reviews, logos, portfolio — or "none yet"]

## Last 3 customers
For each: how they found the business, what they said before buying, what they almost did instead.

## What's actually working
[The real acquisition path, as specifically as known — not vague "word of mouth"]

## What they've tried that didn't work
| Activity | Duration | Outcome | Their theory of why |
|---|---|---|---|
| [e.g. Google Ads on remodel keywords] | 2 months, $800 | 3 quotes, 1 close | "Keywords too broad" |

## Existing alternatives
- [What customers are doing today instead — including DIY and "do nothing"]

## Constraints
- Time: [hours/week]
- Budget: [$/month or none]
- Hard nos: [list]

## 90-day success definition
[Concrete revenue, leads, or milestones]

## Red flags
[Any PMF / retention / messaging issues surfaced above — flag them explicitly. If none, say so.]
```

Keep it tight — one page, max two. Raw data, not analysis.

## Hand off to step 2

> "Got the lay of the land. Next I'll dig into who you actually serve and what job they're hiring you for — that's the step that unlocks everything downstream."

Then load `steps/02_jobs_and_segments.md`.
