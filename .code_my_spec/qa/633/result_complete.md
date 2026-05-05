# QA Result: Story 633 — Public Landing Page

## Status

pass

## Scenarios

### 1. Page loads and renders (AC baseline)

pass

Navigated to `http://localhost:4008/`. Server returned HTTP 200. The page rendered without errors and served `MarketMySpecWeb.HomeLive`, not the Phoenix scaffold.

Evidence: `.code_my_spec/qa/633/screenshots/01_initial_load.png`

### 2. Artifact preview in the hero (Criterion 5665 / 5666)

pass

Element `[data-test="artifact-preview"]` is present in the hero section. Content contains strategy-related words: ICP, Positioning, Channel, Strategy, Founder. No "Lorem ipsum" placeholder text is present. The artifact preview contains five realistic strategy bullets.

### 3. Hero headline present (Criterion 5665)

pass

Element `[data-test="hero-headline"]` is present. The `<h1>` contains the text "Marketing for founders, in Claude Code".

### 4. Install command accessible without auth gate (Criterion 5667 / 5668)

pass

Element `[data-test="install-command"]` is present and contains the text `claude mcp add market-my-spec http://localhost:4000/mcp` — the `claude mcp add` prefix is present. Element `[data-test="copy-button"]` is adjacent and visible. No `[data-test="auth-gate"]` element exists on the page. No `[data-test="signup-primary-cta"]` element exists. Clicked the copy button — no sign-up modal or auth gate appeared.

Evidence: `.code_my_spec/qa/633/screenshots/02_after_copy_click.png`

### 5. BYO-Claude benefit line below the hero (Criterion 5669 / 5670)

pass

Element `[data-test="byo-claude-benefit"]` is present. Text contains "Bring your own Claude" (case-insensitive match for "bring your own claude") and "don't markup your tokens". The BYO-Claude section is rendered as a standalone benefit section below the hero, not as a warning or caveat within the hero.

Evidence: `.code_my_spec/qa/633/screenshots/03_byo_claude_benefit.png`

### 6. Messaging-guide phrase audit (Criterion 5671 / 5672)

pass

Canonical positioning line "Marketing for founders, in Claude Code" is present in the `[data-test="hero-headline"]` element.

Banned phrase check (all absent):
- "10x" — absent
- "go viral" — absent
- "AI-powered marketing" — absent
- "next-gen" — absent
- "revolutionize" — absent
- "Lights out software factory" — absent
- "Elixir-first" — absent
- "specification-driven" — absent

### 7. Agency CTA below install (Criterion 5673 / 5674)

pass

Element `[data-test="agency-cta"]` is present. Text contains "Run an agency?" and "Talk to John about early access." — both "run an agency" and "talk to john" match case-insensitively. The CTA is in a separate `<section>` positioned at the bottom of the page, below the install command block and the feature cards.

Evidence: `.code_my_spec/qa/633/screenshots/04_bottom_of_page.png`

### 8. No equal-weight agency CTA next to install (Criterion 5674)

pass

The install command block is the primary CTA — it is centered prominently in the hero section with a large heading "Marketing for founders, in Claude Code". The agency CTA is in a subordinate `<section>` at the bottom of the page with small, muted text ("Run an agency?") and a secondary link. The agency CTA is clearly not equal weight to the install command.

## Evidence

- `.code_my_spec/qa/633/screenshots/01_initial_load.png` — full-page screenshot of `http://localhost:4008/` showing the HomeLive landing page with all required elements
- `.code_my_spec/qa/633/screenshots/02_after_copy_click.png` — screenshot after clicking the copy button, confirming no auth gate or modal appeared
- `.code_my_spec/qa/633/screenshots/03_byo_claude_benefit.png` — screenshot showing the BYO-Claude benefit section with required copy
- `.code_my_spec/qa/633/screenshots/04_bottom_of_page.png` — screenshot of the bottom of the page showing the subordinate agency CTA

## Issues

None
