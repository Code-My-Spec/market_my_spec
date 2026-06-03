# Clustering Qualitative Records Without Bias

## Executive summary

Letting a model define categories AND rank them in the same pass produces confident-
sounding but structurally circular taxonomies — the model finds what it already knows
to look for. The practitioner fixes are: read before you code, code from data not
labels, and validate clusters against a held-out calibration set hand-coded before the
model ran.

---

## The core trap

When an LLM receives 200 job postings and outputs "here are the 5 clusters, ranked by
frequency," two things have happened invisibly:

1. The model invented categories from its training distribution, not from the data.
2. Frequency claims are about the model's tendency to emit labels, not about the
   actual distribution in the corpus.

This is not an LLM pathology specifically — it's a general qualitative-coding failure
mode. Grounded theory exists precisely because researchers have this problem without
computers.

---

## Canonical sources

### Grounded Theory — Glaser & Strauss (1967), Corbin & Strauss (2008)

Grounded theory's central discipline: categories must be _discovered from the data_,
not imposed before coding begins. The three-stage coding process:
- **Open coding**: read each record line by line and assign raw labels without any
  predefined structure. Do not group yet.
- **Axial coding**: look for relationships between open codes. Group where the data
  forces it, not where the analyst wants to.
- **Selective coding**: identify the core category that explains the most variance.

The critical rule: if you begin with categories, you are doing deductive analysis, not
grounded theory. The order matters.

Applied to the pipeline: the Cluster stage should run open-coding first (assign raw
pain descriptors to each record), then axial grouping (find natural clusters from the
pain descriptors), then rank. Not: "here are the categories I expect, now assign each
record."

Source: Corbin & Strauss, _Basics of Qualitative Research_, 3rd ed., 2008.

### Affinity Diagramming (KJ Method) — Kawakita Jiro (1960s)

The KJ method: write each observation on a card, physically sort cards into piles based
on affinity, name the piles _after_ they form. The key discipline is that naming comes
last — labels emerge from the grouping, not the other way around. Practitioners who
run digital affinity diagrams (MIRO, FigJam) often violate this by naming groups early
and then fitting cards to labels.

The pipeline analog: the LLM should produce one raw pain descriptor per record (like a
card), then cluster the descriptors, then name the clusters. This is the opposite of
"give me 5 categories for these 200 records."

Source: Nielsen Norman Group thematic analysis guide, 2019.
https://www.nngroup.com/articles/thematic-analysis/

### Card Sorting — practitioner discipline against LLM monoculture

Recent research (arXiv 2505.09478, 2025) found that LLM-driven card sorting predicts
the most prominent human-sorting patterns but disagrees significantly on placement of
individual cards and creates "a lack of realistic diversity" in category generation.
The specific failure mode: predefined categories bias the sorter into generating
similarly structured categories — exactly the circular taxonomy problem.

The structural fix from the UX research literature: run the LLM on a _random subsample_
(calibration set) and have a human verify the categories before running the full corpus.
If the human reads 20 records and finds the model's categories nonsensical, the
categories are wrong regardless of how confident the model sounds.

Source: "Card Sorting Simulator: Augmenting Design of Logical Information Architectures
with Large Language Models," arXiv 2505.09478, 2025.

### "Cluster on pain, not words" — a field heuristic

Semantic clustering (embedding similarity, keyword overlap) groups records by topic
vocabulary. Pain clustering groups records by the frustration being expressed. These
produce different results: "GoHighLevel CRM migration" and "moving sub-accounts between
GHL instances" are semantically distant but describe the same pain. The pipeline's LLM
relevance mode (intent + adjacency scoring) is already doing pain-level matching, but
the Cluster stage needs to explicitly ask for pain descriptors, not topic labels.

---

## Mapping to the 5-stage pipeline

**Cluster stage (directly)**

The Cluster stage does not yet exist in the codebase (it's listed in the README as a
planned stage). When built, the correct prompt structure is:

1. For each record individually: "In ≤10 words, describe the pain the client is trying
   to solve. Use their words where possible." → raw pain descriptor per record.
2. Group descriptors by affinity (embedding similarity on the _pain descriptors_, not
   the original text).
3. Name each cluster _after_ grouping. Require a kill argument: "What would make this
   cluster a false category?"
4. Calibrate against a hand-coded sample: read 15 records before running the model,
   assign your own pain descriptors, then check if the model's clusters contain your
   top 3 descriptors.

**Score stage**

The relevance axis already clusters on pain (intent + adjacency), which is correct.
The risk is that the `RELEVANCE_SYSTEM` prompt lists example adjacencies, which seeds
categories. Consider removing examples from the production prompt and moving them to
a calibration file.

---

## Where our intent doc is silent / contradictory

- The intent doc warns about the LLM defining-and-ranking problem but does not specify
  the fix. The grounded-theory separation (describe first, group second, name third) is
  the fix.

- There is no calibration set step in the pipeline. The `relevance_manual.json` file
  (`--relevance manual` mode) is the closest thing — it lets a human pre-score a set of
  records that the model then matches. That pattern should be formalized as a
  "calibration gate": run manual scoring on 15 records, compare to LLM output, only
  proceed if agreement is above a threshold (e.g., 80% directional match on KEEP/KILL).
