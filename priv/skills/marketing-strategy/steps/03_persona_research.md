# Step 3 — Persona Research

Dispatch research agents to validate (or kill) the segments from step 2. This is the biggest external-research investment in the whole flow.

**Mode:** Research agents run in parallel. You orchestrate and synthesize.

**Artifacts:**
- `marketing/research/persona_<segment>.md` — raw research per segment
- `marketing/research/alternatives.md` — what customers use today instead
- `marketing/03_personas.md` — synthesized personas

## Approach

1. For each candidate segment in `marketing/02_jobs_and_segments.md`, dispatch one research agent.
2. Dispatch one additional agent for competitive alternatives (including DIY and "do nothing").
3. Run them **in parallel** — a single message with multiple Agent tool calls, `subagent_type: "general-purpose"`.
4. When reports come back, synthesize into `marketing/03_personas.md`.

## Vertical source lists (pass to agents inline)

The #1 failure mode for persona research is agents using generic sources. Pass the specific platforms that yield authentic voice for the user's business type. Pick the relevant list and paste it into the agent prompt.

**B2B SaaS / software:**
- g2.com, capterra.com, trustradius.com — 3-star reviews especially (most honest)
- reddit.com/r/SaaS, r/sales, r/msp, r/startups
- Hacker News (hn.algolia.com for historical search)
- LinkedIn post comments (not posts themselves)
- Gong public call libraries if applicable

**Dev tools:**
- GitHub issues + discussions, Stack Overflow (by tag)
- r/programming, r/webdev, r/[language]
- Hacker News + Lobsters
- dev.to comments, Discord transcripts (where public)
- Changelog podcast / show notes

**Local trades (granite, roofing, HVAC, landscaping, etc.):**
- Google Maps reviews — 3-star sweet spot for trades
- Yelp, Angi, HomeAdvisor, Houzz project discussions
- Nextdoor neighborhood threads
- r/HomeImprovement, r/Construction, r/HVAC
- Local Facebook groups (where public)

**Consulting / professional services:**
- LinkedIn comment threads on practitioner posts
- Podcast interview transcripts (listennotes.com search)
- Substack newsletter Q&As, comment sections
- r/consulting, r/ExperiencedDevs, r/Lawyertalk, r/medicine (vertical-specific)
- Public Slack community posts (RevGenius, Pavilion, etc.)

**B2C physical / DTC products:**
- Amazon reviews — 3-star especially
- Trustpilot, Sitejabber
- r/BuyItForLife, r/reviews, category-specific subs
- TikTok + YouTube comment sections on review videos
- Pinterest pins for discovery language

**Prosumer / creator / course:**
- Reddit (creator-specific subs)
- Twitter/X replies to competitors
- Substack Notes, YouTube comments
- Gumroad / Teachable public reviews
- Niche Discord servers (where public)

## Research agent prompt template — per segment

Customize per segment. Insert the segment profile from step 2 and the vertical source list from above.

```
I'm validating a customer segment for a [business type — e.g., "residential granite countertop installer in Tampa, FL"]. I need verbatim evidence that this segment is real, reachable, and worth targeting.

Target segment: [profile from step 2 — role, demographic, context, trigger event]
Business the segment would be hiring: [one-line description from step 1]

Investigate and report the following:

1. **Where this segment congregates** — specific URLs and community names. Not categories ("Reddit" is not an answer — "r/HomeImprovement with 2M members, specific threads X and Y" is).

2. **Vocabulary (verbatim)** — 10-15 direct quotes from the segment talking about this problem space. REQUIREMENT: quotes only, in quotation marks, each with source URL and date. No paraphrase. If you cannot find a direct quote for a claim, say "no verbatim evidence found" — do not fabricate.

3. **Top pains and triggers** — what they complain about, what events make them start looking. Tied to specific quotes where possible.

4. **Alternatives they use today** — what they do instead. Include DIY, competing products/services, hacks, and "do nothing." Rank by frequency. Include disconfirming evidence if you find it.

5. **Buying behavior signals** — how they evaluate. What they ask for. What builds trust. What kills the sale.

6. **Red flags** — is this segment actually reachable at reasonable cost? Notoriously hard to sell to? No budget? Signal the segment is a mirage?

Prioritize these source types (in order): 3-star reviews > "switched from X to Y" narratives > unprompted forum complaints > review-aggregate sentiment > 5-star testimonials (deprioritize — least honest).

Required sources for this vertical: [paste the vertical list from SKILL.md or step 3 doc here]

REQUIREMENTS:
- Minimum 3 distinct platforms with citable URLs
- Minimum 15 verbatim quotes across those platforms
- Actively search for disconfirming evidence — if you only find confirming data, note that as a red flag
- Recency: flag any source >18 months old. Weight recent sources more heavily.

Return data in this structure:
{
  "where_they_congregate": [...],
  "vocabulary": [
    {"quote": "...", "source_url": "...", "platform": "...", "date": "...", "sentiment": "positive/negative/frustrated/neutral", "theme": "pain/trigger/outcome/alternative"}
  ],
  "top_pains": [...],
  "triggers": [...],
  "alternatives_used": [...],
  "buying_behavior": [...],
  "red_flags": [...],
  "confidence": "High/Medium/Low/Insufficient",
  "confidence_rationale": "..."
}

Confidence rubric:
- High: ≥15 quotes, ≥3 platforms, <18 months old, includes disconfirming search, consistent themes
- Medium: 6-14 quotes, ≥2 platforms, some themes unresolved
- Low: <6 quotes or single platform
- Insufficient: no citable URLs, heavy vendor-published content — reject

If evidence is thin, return "Insufficient" — do not pad.

Return under 1200 words total.
```

## Research agent prompt — alternatives sweep

Parallel to segment agents:

```
I'm researching competitive alternatives for a [business type]. I need the full map of what customers do today, including non-obvious alternatives.

Business: [one-liner]
Primary segment(s): [from step 2]

Investigate:

1. **Direct competitors** — other providers of the same service/product. Name 5-10 with:
   - Homepage URL (fetch it)
   - One-line positioning (their words, not yours)
   - Pricing model if visible
   - What they're known for / strengths
   - Weaknesses from review sites

2. **Indirect competitors** — different category, same job-to-be-done. E.g., for granite, indirect = laminate, butcher block, quartz, tile. For a consulting practice, indirect = hiring internally, a software tool, doing nothing.

3. **DIY alternatives** — what tutorials, tools, YouTube videos, forum guides exist for someone trying to solve it themselves?

4. **"Do nothing" path** — what's the cost of inaction? Why might someone not solve this at all?

5. **Category gaps** — is anyone positioning in an interesting/differentiated way? Any under-served angles?

Fetch each direct competitor's homepage via WebFetch to get real positioning language (don't paraphrase).

Return under 800 words. Flag the 2-3 alternatives that look most dangerous to the user's business.
```

## While agents are running

> "Dispatched [N] research agents — one per segment plus an alternatives sweep. Usually takes a few minutes. I'll synthesize when they're back."

Don't poll. Don't narrate. Just wait.

## Synthesis — write `marketing/03_personas.md`

When all reports return:

1. Save each raw report to `marketing/research/persona_<segment>.md` and `marketing/research/alternatives.md`.
2. Synthesize into `marketing/03_personas.md`:

```markdown
# Personas — [Business name]

## Persona 1: [memorable name tied to segment]

**Profile**
- [role / demographic / life stage / household or company context]

**Primary job-to-be-done**
[One sentence, grounded in step 2 + research confirmation]

**Trigger events** (from research)
1. [event — "verbatim quote if available"] — [source, date]
2. [event] — [source, date]

**Top pains** (from research)
1. [pain — "quote"] — [source, date]
2. [pain] — [source, date]
3. [pain] — [source, date]

**Desired outcome**
[Quote or close paraphrase of what success looks like in their words]

**Alternatives used today** (ranked by frequency)
- [alt 1] — [% or frequency signal]
- [alt 2]
- [alt 3 — DIY / do nothing]

**Vocabulary** — direct quotes only, no paraphrase
- "[phrase]" — [source URL, date]
- "[phrase]" — [source URL, date]
- "[phrase]" — [source URL, date]
[minimum 5 quotes; more is better]

**Where to reach them**
- [specific community / platform / venue 1]
- [specific community / platform / venue 2]

**Buying behavior**
- How they evaluate: [...]
- What builds trust: [...]
- What kills the sale: [...]

**Confidence: High / Medium / Low**
[Rationale tied to the agent's confidence rubric output]

---

## Persona 2: [...]

## Dropped segments
[Candidates from step 2 that research showed were mirages. For each: which readiness check failed or what disconfirming evidence surfaced.]

## Disconfirming evidence surfaced
[Anything that contradicts the founder's assumptions. This is often the most valuable output — don't bury it.]
```

## Guardrails

- **Fewer than 5 verbatim quotes per persona = label low confidence or drop.**
- **Never invent quotes.** If the agent returns no citable URL for a quote, discard it.
- **Disconfirming evidence belongs in the doc.** If you only report confirming signals, you're doing PR for the founder's assumptions.
- **One-pager per persona max.** Long personas don't get used.
- **Reject cute persona names** unless the user wants them. "Remodeling Rebecca" is usually distracting.

## Hand off to step 4

> "Research done. You have [N] validated personas plus [M] that didn't hold up. Next I'll help you pick ONE to go after first — the beachhead. Hardest decision in the whole flow."

Then load `steps/04_beachhead.md`.
