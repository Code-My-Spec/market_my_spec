# Step 5 — Positioning

Build positioning that makes clear, for the beachhead persona, what you are, why you're different, and why they should choose you over the alternatives they're actually considering.

**Mode:** Synthesis with light research to pull competitor positioning. Use April Dunford's 5-component canvas as the primary artifact, not a one-line template.

**Artifact:** `marketing/05_positioning.md`

## Framework — Dunford's 5-component canvas

April Dunford (*Obviously Awesome*, 2019) **rejects** the single-sentence positioning template ("For X who Y, [product] is a [category] that Z, unlike W") — that's actually Geoffrey Moore's 1991 template, widely misattributed. Dunford: *"I believe this exercise is not only pointless but potentially dangerous."* Filling a blank hides the relationships between components.

Her actual artifact is a canvas, built in order because each component depends on the prior:

1. **Competitive alternatives** — what the customer would do if you didn't exist
2. **Unique attributes** — features/capabilities the alternatives lack
3. **Value + proof** — the benefit each attribute unlocks, with evidence
4. **Best-fit customer characteristics** — who cares a lot about that value
5. **Market category** — the frame of reference that makes the value obvious
6. **Relevant trend** (optional) — only if genuine

Work through them in sequence.

## Component 1 — Competitive alternatives

The #1 positioning mistake is listing "phantom competitors" (vendors buyers never mention) and **ignoring the status quo**, which wins ~20–25% of enterprise deals. Always ask: *"What would the customer do if we didn't exist?"*

Required categories to list:

- **Do nothing** — accept the current pain, defer the project
- **DIY / manual workaround** — spreadsheet, intern, forum tutorial
- **Different category entirely** — e.g., for granite installers: laminate, butcher block, tile
- **Direct vendor competitors** — listed last, not first

Pull this from `marketing/03_personas.md` (the alternatives section) and `marketing/research/alternatives.md`. If those are thin, go back — positioning without a complete alternatives list is guessing.

## Component 2 — Unique attributes

What can you deliver that the alternatives can't, or deliver worse? Not adjectives — specific capabilities, processes, or characteristics.

Weak attributes (reject):
- "Better customer service"
- "High quality"
- "Cutting-edge technology"

Strong attributes (keep):
- "In-house CNC fabrication" (vs. alternatives that outsource, adding 2-week delays)
- "Specialized in Elixir only — the AI model is trained exclusively on Phoenix codebases" (vs. generalist AI tools)
- "Same-day response guarantee" (vs. industry norm of 3-5 day response)

Interview the user:
> "Look at each alternative we listed. For each, what can you do that it can't, or do better? Be specific — no adjectives."

Push back hard on fluff. Keep only attributes that survive the "so what?" test (next section).

## Component 3 — Value + proof

For each unique attribute, answer:

- **Value:** What does this attribute enable the customer to accomplish? Apply "**so what?**" repeatedly until you reach something the buyer cares about.
- **Proof:** How do we know the claim is true?

Example:

| Attribute | So what? | Value | Proof |
|---|---|---|---|
| In-house CNC fabrication | Same-day design changes | Finished kitchen 2-3 weeks sooner than alternatives | 50 past jobs at avg 5-day install vs. industry avg 21 |
| Elixir-only AI training | Model catches Elixir-specific issues | Shipping code doesn't break on idiomatic Phoenix patterns | Benchmark: 94% catch rate on Elixir bugs vs. 61% for GPT-4 generalist |

Kill any value claim without proof. Unprovable claims are vaporware.

Group the attribute-value pairs into **2-4 value themes** — related attributes that deliver related outcomes. These themes become the pillars in step 6.

## Component 4 — Best-fit customer characteristics

Who cares *a lot* about these value themes? This is where step 4's beachhead feeds directly in. Not just demographics — what characteristics of the customer predict they'll value what you uniquely deliver?

Example characteristics:
- "Kitchen-remodel homeowners who want the project done before the holidays" — timing matters
- "Engineering teams already on Elixir/Phoenix 1.7+" — stack compatibility matters
- "Consulting firms at 3-10 partners" — size matters for the service model

Pull directly from `marketing/04_beachhead.md`. If the characteristics and the value themes don't line up, something's wrong — loop back.

## Component 5 — Market category

This is the frame of reference that makes the value obvious. Most positioning failures happen here.

Interview:
> "When this persona describes you to a peer, what *kind of thing* do they say you are?"

Guidelines:

- **Narrow enough to have meaningful differentiation.** "Software" = too broad. "AI code review for Elixir teams" = differentiable.
- **Broad enough to have 3+ recognizable alternatives.** If the category has no competitors, it's probably not a category yet.
- **Honest to buyer language.** If buyers don't use your category name, you've invented jargon. Test by asking if a potential customer would search for your category term.

### Category creation — be skeptical

Dunford disagrees with Play Bigger / category-design gospel for early-stage. Her view: categories emerge; some companies are wise to that. Creating a category means convincing buyers of both the problem and the solution — double the work. It's a 6–10 year play requiring significant capital.

Default for early-stage: **find an existing category you can win, and reshape it from inside.** Don't invent a new one unless you have unusual capital and runway.

## Component 6 — Relevant trend (optional)

A broader market shift that makes your positioning urgent. Only include if genuine. Force-fitting a trend is a documented failure mode.

**Trend honesty test:** if you remove the trend reference, does the positioning still stand? If yes, the trend is decoration and belongs in narrative work (step 6), not positioning.

Examples that work: "the shift to remote work" for collaboration tools in 2020; "AI code generation quality gap" for an Elixir-specific dev tool in 2026.

Examples that don't: "the digital transformation of kitchens" for a granite installer — that's marketing-speak, not a trend.

## Light research — competitor positioning

Before finalizing, fetch 2-3 direct competitors' homepages. For each, via WebFetch:

- Headline (verbatim)
- Sub-headline (verbatim)
- Category they claim
- Emphasized attributes

Save to `marketing/research/competitor_positioning.md`:

```markdown
# Competitor positioning

## [Competitor 1]
- URL: [homepage]
- Headline: "[verbatim]"
- Sub: "[verbatim]"
- Category claim: [...]
- Emphasized attributes: [...]

## [Competitor 2]
[...]
```

This gives you something concrete to position *against*. Dunford: positioning is relative, not absolute.

## Moore's shorthand (optional)

Once the canvas is complete, you can compress it into Moore's one-liner as a handoff artifact:

> For **[best-fit customer]** who **[trigger/JTBD]**, **[product name]** is a **[category]** that **[value theme]**, unlike **[main alternative]** which **[limitation]**.

Use this for elevator pitches or sales enablement. Don't use it *instead of* the canvas — the canvas is the thinking work; the one-liner is the compression.

## Validation tests

Run every test. If any fail, revise.

| Test | Question |
|---|---|
| Duck test | Does the positioning clearly name what the product/service is? |
| Category test | Could someone classify the product just from the category? |
| Swap test | Could a competitor truthfully put their own name in your positioning? (If yes → too generic) |
| Consequence test | If someone picks the alternative, do they pay a tangible cost? (If no → value isn't valuable) |
| "So what?" test | Does each value claim survive 3 rounds of "so what?" |
| Trend honesty test | If you remove the trend, does positioning still stand? (If the positioning falls apart without the trend, the trend was doing work it shouldn't) |
| Sales-pitch flow test | Can the founder walk from alternatives → unique attributes → value → why-now in 10 minutes without the prospect asking "but how are you different from X?" |
| Best-at-something test | Can you truthfully complete "We are the best [category] for [segment] who want [value]"? If not, positioning is soft. |

## Anti-patterns (Dunford's documented failure modes)

- Listing phantom competitors; ignoring status quo / DIY / do-nothing
- Assuming only one possible market frame exists — there are always several
- Customers comparing you to vendors you don't consider competitors = positioning is off
- Speaking buyer-alien language (Dunford's trucking example: "AI/Uber for freight" meant nothing to Midwest supply-chain managers — they used different terms)
- Force-fitting a trend that doesn't carry the argument
- Defining best-fit customer too broadly — lets bad-fit deals skew the team's sense of product-market fit

## Write the artifact

Write `marketing/05_positioning.md`:

```markdown
# Positioning — [Business name]

## 1. Competitive alternatives
- **Do nothing / status quo:** [specific description]
- **DIY / manual workaround:** [specific]
- **Different category:** [alternatives in adjacent categories]
- **Direct competitors:** [named vendors]

## 2. Unique attributes
1. [attribute — specific, not adjective]
2. [attribute]
3. [attribute]

## 3. Value + proof
| Attribute | Value (after "so what?") | Proof |
|---|---|---|
| [attr] | [value] | [evidence] |

### Value themes
1. **[Theme 1]:** [related attributes + outcome]
2. **[Theme 2]:** [...]
3. **[Theme 3]:** [...]

## 4. Best-fit customer characteristics
[From step 4 beachhead — characteristics that predict they'll care about the value themes]

## 5. Market category
- **Category name:** [what peers would call this]
- **Why this frame:** [why this category makes unique value obvious]
- **Category check:** [is it narrow enough to differentiate + broad enough to have competitors?]

## 6. Relevant trend (optional)
[Genuine trend that makes this urgent — or "none used" if the positioning stands without one]

## Moore shorthand (optional handoff artifact)
> For [best-fit customer] who [trigger/JTBD], [product] is a [category] that [value theme], unlike [main alternative] which [limitation].

## Validation tests
- Duck test: [pass/fail + note]
- Category test: [pass/fail + note]
- Swap test: [pass/fail + note]
- Consequence test: [pass/fail + note]
- "So what?" test: [pass/fail + note]
- Trend honesty: [pass/fail + note]
- Sales-pitch flow: [pass/fail + note]
- Best-at-something: [pass/fail + note]

## What this positioning rules out
[Customers, use cases, angles, and channels that no longer fit. Being explicit prevents drift.]
```

## Hand off to step 6

> "Positioning canvas complete. Now I'll turn it into the external-facing messaging — headline, sub, pillars mapped to the value themes, and proof points. That's what goes on your site and into every piece of content."

Then load `steps/06_messaging.md`.
