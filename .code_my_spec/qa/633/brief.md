# QA Brief: Story 633 — Public Landing Page

## Tool

web (Vibium MCP browser tools)

## Auth

No auth required. The landing page at `http://localhost:4007/` is fully public — anonymous visitor only.

## Seeds

No seeds required for this story. The landing page renders without any database records.

Run the server if not already running:

```
PORT=4007 mix phx.server
```

## What To Test

### 1. Page loads and renders (AC baseline)

- Navigate to `http://localhost:4007/`
- Confirm the page returns HTTP 200 (curl check)
- Capture a full-page screenshot of the initial state

### 2. Artifact preview in the hero (Criterion 5665 / 5666)

- Look for element with `data-test="artifact-preview"` in the hero section
- Verify it is present and non-empty
- Verify content contains strategy-related words (positioning, ICP, channel, strategy, or founder)
- Verify no "Lorem ipsum" placeholder text

### 3. Hero headline present (Criterion 5665)

- Look for element with `data-test="hero-headline"`
- Verify it is present

### 4. Install command accessible without auth gate (Criterion 5667 / 5668)

- Look for element with `data-test="install-command"`
- Verify it contains the text `claude mcp add`
- Look for element with `data-test="copy-button"` alongside the install command
- Verify no `data-test="auth-gate"` element is present
- Verify no `data-test="signup-primary-cta"` element is present as the primary CTA
- Click the copy button; verify no sign-up modal or auth gate appears after clicking

### 5. BYO-Claude benefit line below the hero (Criterion 5669 / 5670)

- Look for element with `data-test="byo-claude-benefit"`
- Verify it contains text matching "bring your own claude" (case-insensitive)
- Verify it contains text matching "don't markup your tokens" (case-insensitive)
- Verify the BYO-Claude copy is positioned as a benefit, NOT as a warning/caveat in the hero

### 6. Messaging-guide phrase audit (Criterion 5671 / 5672)

- Get the full page text
- Confirm canonical positioning line "Marketing for founders, in Claude Code" is present
- Confirm the following banned phrases are absent:
  - "10x" (word boundary)
  - "go viral"
  - "AI-powered marketing"
  - "next-gen"
  - "revolutionize"
  - "Lights out software factory"
  - "Elixir-first"
  - "specification-driven"

### 7. Agency CTA below install (Criterion 5673 / 5674)

- Look for element with `data-test="agency-cta"`
- Verify it contains text matching "run an agency" (case-insensitive)
- Verify it contains text matching "talk to john" (case-insensitive)
- Verify the agency CTA is NOT positioned as equal-weight to the install command CTA

### 8. No equal-weight agency CTA next to install (Criterion 5674)

- Verify the install command is the primary/dominant CTA
- The agency CTA should be below the install section, not adjacent or equal weight

## Result Path

`.code_my_spec/qa/633/result.md`
