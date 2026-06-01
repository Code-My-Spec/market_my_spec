# No content asset registry; agent operator is the lookup table for matching threads to blog posts

Filed 2026-05-24 from MMS MCP usage during the CodeMySpec marketing cycle. **Priority: low** — workflow friction, not a blocker.

## Problem

Every staged touchpoint requires the agent to manually:

1. Read the thread title + top comments
2. Cross-reference against the operator's known content assets (currently ~3 blog posts on codemyspec.com)
3. Pick the best matching asset
4. Construct the destination URL with the right UTM params (`utm_source`, `utm_medium`, `utm_campaign`)

The agent is the lookup table. There's nothing in MMS that knows about the operator's content assets, what topics they cover, or what UTM scheme to use. This produces three failure modes:

1. **Inconsistent UTM tagging.** Each agent run can construct slightly different campaign slugs, breaking downstream analytics reads (GA4 sees `claudeai:vir-claude-code-forgetting` and `claudeai_vir_memory` as different campaigns).
2. **Asset mismatches.** Agent picks a sub-optimal post because it didn't recall a better one existed. No global ranking pass.
3. **Single point of failure.** Agent context loss = lookup table loss. Asset matching has to be re-done from scratch each session via memory recall.

## Proposed design

1. **`ContentAsset` model**: `slug`, `title`, `canonical_url`, `topic_tags: [string]`, `utm_template` (e.g. `?utm_source={source}&utm_medium={medium}&utm_campaign={campaign}`).
2. **CRUD MCP tools**: `register_content_asset`, `list_content_assets`, `update_content_asset`, `delete_content_asset`.
3. **Thread → asset matching on `run_search`**: each candidate gets a `suggested_assets: [{asset_id, slug, confidence}]` array, ranked by topic-tag/keyword match against title + snippet. Lightweight (TF-IDF or embedding-based, doesn't need to be perfect).
4. **`stage_response` accepts `content_asset_id`**: when set, the UTM URL is auto-constructed from the asset's `utm_template` + the campaign slug. Touchpoint records `content_asset_id` for downstream reporting.
5. **Reporting query**: `engagements_by_asset(asset_id, since, until)` returns the touchpoints that drove traffic to a given asset — closes the loop on "which content earns engagements."

## Acceptance criteria

1. `ContentAsset` schema + migration shipped.
2. CRUD MCP tools registered.
3. `run_search` response envelope extended with `suggested_assets` per candidate.
4. `stage_response` accepts `content_asset_id`; touchpoint records it; UTM URL auto-built from template.
5. Docstring on `stage_response` documents the new param.
6. Optional: a `seed_default_content_assets` task for new accounts that pre-populates with the operator's content sitemap if one is provided.

## Out of scope

- Full sitemap ingestion / auto-discovery of content assets from a domain. Operator registers assets explicitly.
- Multi-domain content asset management (cross-property campaigns). Single domain per account for v1.
- Asset performance scoring / "this asset over-converts on these subs" recommendations. That comes later, after data accumulates.

## Reference

- Caller-side: every `stage_response` call today (touchpoints `40b4f8bf`, `2641ac95`, `898d3c7a`, `16b0d508`) included a manually-constructed UTM campaign slug. Agent maintains the asset registry in memory across the session.
- Related: `run-search-result-pagination.md` (the `suggested_assets` field adds payload per candidate; pagination keeps it bounded).
- Adjacent roadmap item: the "build-in-public" feature exposing CMS rules / scenarios / GWT publicly is asset-registry-adjacent but a separate concern (CMS exposing its internal artifacts vs MMS knowing about external content assets).
