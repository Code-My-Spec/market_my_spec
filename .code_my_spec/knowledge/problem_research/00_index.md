# Problem Research Knowledge Base

## What this is

Practitioner-grade synthesis on data-driven problem research and validation, built to
inform the design of the **"Frame Problem" skill** in MarketMySpec. The skill wraps a
validated Python pipeline: `discover(problem) → Board` (Frame → Gather → Cluster →
Score → Red-team). Each file here maps practitioner wisdom to a specific stage.

## Who it's for

A solo founder who already has a working Upwork-scraping discovery pipeline and wants
to (a) understand the theoretical grounding for the design choices already made, and
(b) find the gaps the pipeline doesn't yet cover.

## Files

| File | Topic | Pipeline stage(s) |
|------|--------|-------------------|
| `01_money_as_validation.md` | Paid > clicks > says hierarchy | Score (money gate) |
| `02_framing_fuzzy_problems.md` | Turning hunches into testable hypotheses | Frame |
| `03_marketplace_signal_extraction.md` | Upwork and other demand-signal sources | Gather |
| `04_clustering_qualitative_records.md` | Avoiding biased taxonomies | Cluster |
| `05_red_teaming_candidates.md` | Structural prosecution of KEEP rows | Red-team |
| `06_pipeline_anti_patterns.md` | What goes wrong in discovery efforts | All stages |
| `99_design_critique.md` | Full critique of the 5-stage pipeline | All stages |

## The through-line

Every file converges on a single principle borrowed from the pipeline's own README:
**"The LLM does the volume work. Reality decides."** The practitioner literature
uniformly agrees that stated intent is unreliable. Observed economic behavior — someone
already handing over money for the exact pain — is the only signal worth gating on.
Everything else (surveys, interviews, upvotes, HN comments) is input to the Frame
stage, not validation.
