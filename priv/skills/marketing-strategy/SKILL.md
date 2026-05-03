---
name: marketing-strategy
description: Develop an initial marketing strategy from scratch via a guided 8-step flow — interviews the user, dispatches research agents for customer personas and competitive alternatives, synthesizes positioning, messaging, channels, and a 90-day plan. Works for any business type (software product, consultant/services, trades, local business). Use when the user wants to "build a marketing strategy", "figure out marketing", "define my ICP", "find my customers", "pick marketing channels", "write positioning", or is a founder/operator with no existing written strategy. Also use to iterate on an existing strategy when `marketing/` already exists.
user-invocable: true
argument-hint: [optional focus, e.g. "start from step 3" or "just redo positioning"]
---

# Marketing Strategy

You are guiding a founder or operator through building an initial marketing strategy. This skill walks the canonical 8-step sequence (STP + Dunford + Bullseye hybrid): interview current state, define ICP and jobs-to-be-done, research personas, pick a beachhead, draft positioning, write messaging, select channels, lock in a 90-day plan.

**This skill is industry-agnostic.** The user may be building a software product, selling consulting services, installing granite countertops, running a law practice, opening a restaurant, or anything else. Do not default to dev-tool, SaaS, or tech examples unless the user's business is actually one of those. Draw examples from their industry.

## How to run this skill

**Progressive disclosure.** The 8 steps each live in `steps/NN_*.md`. Do **not** read them all upfront. Orient first, then load one step at a time as you get to it.

```
skills/marketing-strategy/
├── SKILL.md              ← you are here
└── steps/
    ├── 01_current_state.md
    ├── 02_jobs_and_segments.md
    ├── 03_persona_research.md   ← dispatches research agents
    ├── 04_beachhead.md
    ├── 05_positioning.md        ← light research (competitor pages)
    ├── 06_messaging.md
    ├── 07_channels.md           ← light research (channel tactics by ICP)
    └── 08_plan.md
```

## Step 0 — Orient

Before touching anything, do these in parallel:

1. Check whether `marketing/` already exists in the user's working directory. If it does, list its contents and read any step artifacts already written. This tells you whether you're running the first-time flow or **iteration mode** (see bottom of this doc).
2. Skim obvious project context: `README.md`, `package.json`, `mix.exs`, `Gemfile`, a landing page HTML file, or whatever signals the business type. For a contractor, this might just be a one-page site or a Google Business Profile — that's fine.
3. If the user gave you a URL or product name in arguments, fetch it with WebFetch before asking a single question. Don't make the user type things you can read.

Greet the user briefly, confirm the business (or ask in one sentence if you have zero signal), and confirm they want to run the full 8-step flow or jump to a specific step.

## The 8 steps

| # | Step | Mode | Artifact |
|---|---|---|---|
| 1 | Current state | Interview | `marketing/01_current_state.md` |
| 2 | Jobs & segments | Interview | `marketing/02_jobs_and_segments.md` |
| 3 | Persona research | **Research agents** | `marketing/03_personas.md` + `marketing/research/` |
| 4 | Beachhead | Synthesis | `marketing/04_beachhead.md` |
| 5 | Positioning | Synthesis + light research | `marketing/05_positioning.md` |
| 6 | Messaging | Synthesis | `marketing/06_messaging.md` |
| 7 | Channels | Synthesis + light research | `marketing/07_channels.md` |
| 8 | 90-day plan | Synthesis | `marketing/08_plan.md` |

For each step:

1. Read `steps/NN_*.md` when you reach it — not before.
2. Follow the instructions in that doc (interview questions, research agent prompts, or synthesis guidance).
3. Write the artifact to `marketing/` as the step completes. Don't batch — if the user bails after step 3, they should still have three usable files.
4. Between steps, give the user a one-sentence transition: what's done, what's next.

## Operating principles

- **Interview one or two questions at a time.** Never dump a long questionnaire. Wait for answers, react to them, follow up.
- **Use what the user gives you.** Website, existing reviews, Google Business Profile, an old about-page — read it before asking about it.
- **Adapt to the business type.** A SaaS founder and a countertop installer have different channels, vocabularies, and customer behaviors. Don't force software frameworks onto non-software businesses. When step docs mention dev-tool examples, treat them as one case among many.
- **Ground personas in evidence.** Step 3 dispatches research agents because invented personas are worse than no personas. Don't skip it.
- **Be concrete.** "Homeowners aged 45-65 in the $800K+ home bracket doing kitchen remodels after their last kid leaves for college" beats "homeowners who want nice counters."
- **Write artifacts as you go.** Each step produces a file before moving on.
- **Cut scope ruthlessly.** One sharp ICP beats four fuzzy personas. Two channels the user will actually run beats seven they won't.

## Iteration mode

If `marketing/` already exists with prior artifacts:

1. Read what's there.
2. Ask: "What's changed since last time? What worked, what didn't, what surprised you?"
3. Identify which step(s) need updating — often one or two, not all eight. Common patterns:
   - New customer data → revisit steps 2, 3, 4 (jobs, personas, beachhead)
   - A channel isn't working → revisit step 7, possibly 5 (positioning might be off)
   - Revenue plateau → revisit step 4 (wrong beachhead) before blaming execution
4. Update the relevant step artifacts in place. At the bottom of each updated file, add a short `## Revision — YYYY-MM-DD` section noting what changed and why.

## What this skill does NOT do

- Write finished blog posts, ads, landing pages, or emails — that's downstream content work
- Set up analytics, CRMs, email tools, or ad accounts — that's tooling setup
- Produce a 40-slide marketing plan deck — this is a working strategy, not a board doc
- Do ongoing content scanning (Reddit, Twitter, news) — that's a separate operational skill

The goal is a compact, evidence-backed strategy the user can execute against starting tomorrow morning, and iterate on over time.
