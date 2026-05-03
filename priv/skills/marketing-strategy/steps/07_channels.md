# Step 7 — Channels (Bullseye)

Use Traction's Bullseye framework to brainstorm all plausible channels, test 3 in parallel, and focus on the one winner. Bias toward where the beachhead persona actually is (from step 3 research). Respect the user's constraints (from step 1).

**Mode:** Synthesis + light research for channel tactics.

**Artifact:** `marketing/07_channels.md`

## Framework — Bullseye (full 5-step process)

From Weinberg & Mares, *Traction* (2015). Most skip the first step, which is the whole point.

1. **Brainstorm** — reasonable ideas for *every* channel, including ones you'd dismiss. Forces you past the 2-3 you already like.
2. **Rank into rings** — Outer (possible), Middle (promising, pick 3), Inner (core focus, 1).
3. **Prioritize** — pick the middle-ring 3.
4. **Test** — run cheap, parallel experiments in the middle ring. Key question: *"Can this channel work for us? At what CAC? At what volume?"* — not "does it work at scale." Time-boxed: ~$1K–$5K or 3–4 weeks per channel.
5. **Focus** — promote one winner to the inner ring; exploit until diminishing returns, then re-run Bullseye.

The step founders systematically skip: **step 1 Brainstorm, including channels that feel unnatural.** Weinberg's whole thesis is that founders under-weight channels they'd personally dislike.

## The channel list (2026-updated)

Traction's 19 channels from 2015, updated for 2026. Pick the ones that apply:

**Still load-bearing:**
- **SEO** — organic search. Long payback; compounds.
- **SEM / Paid search** — Google/Bing Ads. High-intent queries.
- **Content marketing** — blog, YouTube, podcasts. Compounds; needs consistency.
- **Email marketing** — owned list; nurture + conversion. Requires list-building first.
- **Viral marketing** — built-in sharing. Rare outside software.
- **Sales / outbound** — direct outreach, cold email, calls, door-to-door. High-ACV or trust-heavy.
- **Business development** — partnerships, distribution, co-marketing. Strong for services/B2B.
- **Affiliate programs** — pay per referred conversion.
- **Existing platforms** — build on App Store, Shopify, HomeAdvisor, Thumbtack, Etsy, Salesforce AppExchange.
- **Community building** — run a community. Slow-burn, compounding.
- **PR (earned)** — press, trade pubs, local news, industry newsletters.
- **Speaking engagements** — conferences, podcasts as guest.
- **Trade shows** — still dominant for some trades and B2B.
- **Offline events** — meetups, workshops, dinners, open houses. Local services + B2B.
- **Engineering as marketing** — free tools, calculators. Software-adjacent.

**Diminished / merge:**
- **Display ads** — mostly dead outside retargeting. Fold into "paid social."
- **Offline ads (print/radio/TV/billboards)** — niche; keep for local trades only.
- **Unconventional PR (stunts)** — still works; fold into PR.

**Added for 2026:**
- **Short-form video organic** — TikTok, Instagram Reels, YouTube Shorts. Distinct mechanics from "viral."
- **LinkedIn organic** — posts + newsletters. Dominant B2B channel post-2022.
- **YouTube long-form** — own channel; different from short-form.
- **Creator / influencer partnerships** — paid + affiliate hybrid.
- **Podcast guesting** (not hosting) — separate from speaking.
- **Newsletter sponsorships** — Substack, Beehiiv, industry newsletters.
- **Community platforms** — Discord, Slack, Circle, Geneva. Distinct from "building a community."
- **AEO / LLM visibility** — getting cited by ChatGPT, Perplexity, Claude, Gemini. Structured FAQ content, Reddit presence (heavily weighted in LLM retrieval), Wikipedia-adjacent authority, schema markup.
- **Marketplace / directory SEO** — G2, Capterra, Product Hunt, Yelp, Houzz, Thumbtack. Distinct from general SEO.

That's ~24 channels. Use the list as a checklist during Brainstorm.

## Playbook anchors by business type

Pull tactics from the practitioner literature for the user's business type:

- **Dev tools:** a16z Developer Marketing Playbook (Adam Gross, Martin Casado), Heavybit's DevGuild talks, First Round ("How Vercel builds," "The developer marketing playbook"). Defaults: technical content SEO, OSS as wedge, community (Discord), docs-as-marketing, dev-influencer sponsorships, conference talks.
- **Local trades:** Joy Hawkins / Sterling Sky, Greg Gifford, Ryan Stewart (From The Future) local playbooks. Defaults: Google Business Profile + review velocity, local SEO (city+service pages), Nextdoor, Houzz/Thumbtack, referral programs, Facebook local groups.
- **B2B consulting:** Alan Weiss *Million Dollar Consulting*, David C. Baker *Business of Expertise*, Blair Enns *Win Without Pitching*. Defaults: referrals, speaking, books/IP, thought-leadership content, podcast guesting.
- **Prosumer / creator:** Billy Broas *Simple Marketing System*, Jay Clouse Creator Science, Nathan Barry's ladder. Defaults: one platform-native channel (YouTube or LinkedIn) + newsletter.
- **B2C physical / DTC:** Shopify blog, Indie Hackers case studies, Klaviyo playbooks. Defaults: Meta/TikTok paid, creator UGC, Amazon, influencer seeding, email/SMS, retention > acquisition past month 3.

## Step 1 — Brainstorm (outer ring)

Working with the user, list every channel that could plausibly work given:

- The beachhead persona's actual behavior (from `marketing/03_personas.md` — specifically the "where to reach them" section)
- The business type (software / service / trade / B2B / B2C)
- The trigger event pattern (do they search, ask friends, see an ad, walk in?)
- The user's constraints and hard-nos

**Don't filter yet.** Generosity catches channels the user would otherwise dismiss. If the user flat-refuses a channel, note it but still list it — sometimes the best move is challenging a reflexive no.

Paste the 24-channel list as a checklist so nothing gets skipped.

## Step 2 — Light research on promising candidates

Before moving candidates to the middle ring, do a light research pass on the 3–5 most plausible. Dispatch a general-purpose agent if several need investigation, or use WebSearch + WebFetch directly for one or two.

Example per-channel research prompt:

```
I'm evaluating [channel, e.g., "Houzz as a customer acquisition channel"] for [business, e.g., "residential granite countertop installer in Tampa"]. Target persona: [brief persona summary from step 3].

Investigate:
1. Current best practices for [channel] in this business category (2024-2026 sources only)
2. Realistic CAC or effort-per-customer (cite sources)
3. Typical time-to-first-result
4. Common failure modes
5. 2-3 real examples of operators in this category doing it well — with links

Return under 500 words. Be honest: is this channel oversaturated, underused, or unproven for this business type?
```

Save to `marketing/research/channel_<name>.md`.

## Step 3 — Rank to middle ring (pick 3)

For each candidate, score:

| Criterion | Question |
|---|---|
| **Persona fit** | Is the beachhead persona there in volume, in the right mindset? |
| **Constraint fit** | Respects the user's time/budget/hard-nos from step 1? |
| **Time to signal** | Will the user know in 3–4 weeks if it's working? |
| **CAC / effort** | Reasonable acquisition cost for this business's economics? |
| **Compounds or burns?** | Does effort build (SEO, content, community) or vanish (ads)? Mix matters. |
| **Differentiation fit** | Does it showcase the positioning's unique value? |
| **Founder-personality fit** | Will the user actually sustain the work? An introvert picking live speaking = bad. |

Pick 3 for the middle ring.

## Step 4 — Test the middle ring (parallel, time-boxed)

This is the part most plans skip. Run 3 cheap experiments in parallel, ~3–4 weeks each. The question is *"can this work for us at what CAC?"* — not "does it scale."

For each middle-ring channel, spec:

- **Specific activity** — not "do SEO" but "publish one 1500-word comparison page per week targeting [keyword cluster] with KD<20, internal-link to one money page"
- **Time budget** — hours/week, honest (most fail here)
- **Dollar budget** — $/month, honest
- **2-week leading signal** — minimum threshold to keep going (see below)
- **Kill criteria** — the number below which you stop

### Kill criteria by channel type (benchmarks)

These are defaults — adjust to the user's industry. All assume a 3–4 week test window.

| Channel | Kill signal |
|---|---|
| **SEO** | Zero indexed pages ranking in top 50 after 90 days of 2 posts/week |
| **Cold outbound** | <3% positive reply rate across 200 personalized sends |
| **Paid search/social** | CPL >2× target after $1K spent |
| **LinkedIn organic** | <500 avg impressions/post after 30 posts |
| **Short-form video** | <1K avg views after 30 posts |
| **Podcast guesting** | <1 meaningful inbound per 5 appearances |
| **Local SEO / GBP** | <10% increase in GBP views/month after 90 days of review-solicitation |
| **Community hosting** | <20 weekly engaged members after 90 days |
| **Partnerships** | <1 meaningful conversation per 10 outreach attempts |

Kill criteria must be written **before** starting the test. Sunk-cost continuation is the default failure mode without them.

## Step 5 — Focus on the winner

Promote the one winner to the inner ring. Exploit until diminishing returns. Then re-run Bullseye — don't guess at channel #2 before the winner is plateauing.

## Specific-activity defaults by channel (solo operator)

Use these as starting points. Adjust to context.

| Channel | Solo-operator activity |
|---|---|
| **SEO** | 1 bottom-funnel comparison page + 1 "how to [job]" per week; target KD<20; internal-link to one money page |
| **Cold outbound** | 50 personalized sends/day, one offer, 3-step sequence, measured reply rate |
| **LinkedIn organic** | 1 post/day, 4 formats rotated (story, contrarian take, framework, case study), DM responders within 24h |
| **Podcast guesting** | 10 pitches/week to shows with 1K–10K downloads in the niche |
| **Local SEO** | GBP fully optimized, 1 review ask per completed job, 10 city/service page variants |
| **Short-form video** | 1 post/day, hook-first, 3 content pillars, repurpose across Reels + Shorts + TikTok |
| **Community hosting** | Weekly ritual event, 1 signature format, host (don't just join) |
| **Partnerships / BD** | 2 outreach conversations/week to complementary providers, shared-value framing |
| **PR / earned** | 1 story pitch/week to trade publications, tied to a specific angle |

## Common failure modes

- **"We'll do all of them"** — violates singular-inner-ring rule. Hold the line at 3 middle-ring parallel tests, 1 inner-ring focus.
- **"Content marketing"** as a channel — too vague; specify format × platform × topic cluster.
- **Founder-personality mismatch** — introvert picking speaking, non-writer picking SEO. Kills via execution attrition.
- **No kill criterion set upfront** — sunk-cost continuation for 18 months.
- **Copying a winner's *current* channel instead of their early channel** — Notion does paid now; they started with template/community.
- **Confusing traction channel with tactic** — SEO is the channel; "publish comparison pages" is the tactic.
- **Channel-stacking before product-market fit** — paid spend amplifies whatever's on the landing page, including a weak offer.

## Write the artifact

Write `marketing/07_channels.md`:

```markdown
# Channels — [Business name]

## 1. Brainstorm (outer ring)
[Full list of plausible channels — pasted from the 24-channel list with one-line applicability note for each]

## 2. Middle ring (3 candidates to test)

### Candidate 1: [channel name]
- **Why this channel:** [tied to persona research]
- **Specific activity:** [what you'll literally do]
- **Time budget:** [hours/week]
- **Dollar budget:** [$/month]
- **3–4 week leading signal:** [minimum threshold]
- **Kill criterion:** [specific number]

### Candidate 2: [channel name]
[same structure]

### Candidate 3: [channel name]
[same structure]

## 3. Inner ring (if already clear; otherwise determined post-test)
[The one channel that the user will focus on after the middle-ring test phase. If not clear yet, note "TBD after 3-4 week test period."]

## 4. Channels explicitly ruled out
[Channels the user will be tempted by but we're not testing. One-sentence reason each — often tied to hard-nos or personality fit.]

## 5. Review cadence
- Weekly (30 min): check leading signals, decide continue/adjust
- End of test window (3–4 weeks): kill or promote
- Post-focus: exploit winner until plateau, then re-run Bullseye
```

## Hand off to step 8

> "Channels tested and ranked. Final step — turn this into a 90-day plan with goals, a weekly rhythm, and what to do if things aren't working. This is the document you open every Monday."

Then load `steps/08_plan.md`.
