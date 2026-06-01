# ElixirForum venue identifiers return `:unknown_category` on `run_search`

Filed 2026-05-22 from MMS MCP usage during the CodeMySpec marketing cycle. **Updated 2026-05-24** with verified category data from the ElixirForum public Discourse API. Three of the four configured venue slugs do not exist; the fourth (`questions-help`) is correct.

## Problem

ElixirForum venues are listed as enabled in MMS but every search against three of the four configured slugs produces zero candidates because the slugs don't match real categories on the forum. Confirmed via `https://elixirforum.com/site.json` and `https://elixirforum.com/categories.json`.

## Configured vs actual

| MMS venue | Adapter rejects? | Real top-level category | Notes |
|---|---|---|---|
| `chat` | ❌ `:unknown_category` | `chat-discussions` (id 165) | Top-level chat category. The active AI sub-category lives under this. |
| `questions-help` | ✅ accepts | `questions-help` (id 171) | Already correct. |
| `your-libraries` | ❌ `:unknown_category` | Doesn't exist at top level | Closest matches: `announcing` (id 159, sub of News 158) or `blogs` (id 60, sub of blogs-podcasts 155). May have been renamed from a previous ElixirForum structure. |
| `phoenix-forum` | ❌ `:unknown_category` | Doesn't exist at top level | Closest match: `phoenix-news` (id 52, sub of News 158). Phoenix-specific discussion appears to have been folded into News. |

## Critically: the active AI venue is missing entirely

The most active AI/agent venue on ElixirForum is **`ai-llms` (id 169, sub of `chat-discussions` 165)**. This is where 74851 ("Engineering leads, what are you doing to stop the slop?", 159 replies) and 75168 ("How to measure AI code quality?", 58 replies) live. It is not currently configured as an MMS venue.

Adding `ai-llms` as a venue is the single highest-leverage fix for CMS ElixirForum lead scanning. Half of the AI-aligned threads we'd want to engage on are in this sub-category.

## Why it matters

Half the CMS strategy targets ElixirForum venues (per `marketing/07_channels.md` — tier-1 channels include Phoenix forum and library-announce venues). MMS currently surfaces zero ElixirForum leads. The Elixir lead-scan side of cycle stages 1+2 is silently degraded — operators see "no results" and don't realize the venues are misconfigured.

Today's verification took ~15 minutes of WebFetch against Discourse's public JSON API. Confirmed via direct URL inspection of category IDs and slugs.

## Acceptance criteria

1. **Re-seed the prod + dev ElixirForum venues** with verified slugs from the table above:
   - Remove or rename `chat` → `chat-discussions`
   - Remove or rename `your-libraries` → either `announcing` or whatever the operator chooses; the current slug doesn't exist
   - Remove or rename `phoenix-forum` → `phoenix-news`
   - **Add `ai-llms`** as a new venue (sub of chat-discussions). High priority — it's the active AI thread venue.
   - Keep `questions-help` as-is.
2. **Support sub-category venues in the adapter.** ElixirForum uses nested categories (e.g., `chat-discussions/ai-llms`). The adapter must accept sub-category slugs the same way it accepts top-level. Test with `ai-llms` (sub of `chat-discussions`).
3. **Update `add_venue` validation** to reject unknown ElixirForum identifiers at venue-creation time, not at search time. Today the venue creates successfully and only fails when searched — wrong place to surface the error.
4. **Document the canonical identifier list** in the `add_venue` docstring or a separate venue-catalog reference. Operators should not have to figure this out from JSON probes.
5. **Verification:** `search_engagements` against `ai-llms` returns at least one candidate (the venue has 12 recent threads as of 2026-05-24).

## Out of scope

- Adding NEW ElixirForum venues beyond fixing the existing ones + `ai-llms`. Other sub-categories (e.g., `learning-resources/teaching-elixir`, `chat-discussions/jobs`) can be added later if the strategy targets them.

## Reference

- Caller-side discovery: `code_my_spec_marketing/marketing/daily/2026-05-22.md` (MMS gap #3), reconfirmed 2026-05-24 during the social engagement loop.
- Verified data sources:
  - `https://elixirforum.com/categories.json` — top-level category list
  - `https://elixirforum.com/site.json` — full category index including sub-categories with parent_category_id
  - `https://elixirforum.com/c/ai-llms/169.json` — category 169 listing confirms `ai-llms` is the AI/LLMs venue
  - `https://elixirforum.com/t/74851.json` — topic 74851 confirms category_id 169
