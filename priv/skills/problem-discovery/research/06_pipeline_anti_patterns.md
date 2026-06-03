# Pipeline Anti-Patterns

## Executive summary

Problem-discovery pipelines fail in six recurring ways, each with a structural fix.
The pipeline's current design already guards against three of them. The remaining
three — narrative-driven framing, loud-minority bias, and confirmation loop on
relevance — need explicit structural additions.

---

## Anti-pattern 1: Survivorship Bias

**What it is:** You see only the people who complained publicly or posted on Upwork.
You don't see the people who solved the problem in-house, hired an agency offline, or
simply lived with it.

**Concrete example:** The CRM migration opportunity brief is built entirely on Upwork
postings — people who outsourced. It is blind to agencies that solved the problem
internally (no posting) or via a long-term retainer (not discoverable). The real
market could be 10x or 0.1x of what Upwork shows.

**Structural fix:** The pipeline already acknowledges this in opportunity_brief.md
("one platform, one week, one channel"). The fix is adding a "coverage note" to the
Frame artifact: explicitly list the populations NOT covered by the Gather strategy, and
estimate the direction of the resulting bias (Upwork over-counts outsourcers,
under-counts in-house solvers).

Sources: Renascence.io on biased sampling; Wikipedia survivorship bias.

---

## Anti-pattern 2: Narrative-Driven Sampling

**What it is:** The query string is chosen to confirm the story the founder already
believes, not to test it. The pipeline finds what it was told to look for.

**Concrete example:** If you frame the query as "GoHighLevel agency migration" after
reading one tweet about GHL, you'll surface GHL jobs. The corpus will feel validating.
But you've anchored on a specific platform before the data could tell you whether the
pain is platform-specific or generic.

**Structural fix:** The `framings_migration.txt` multi-framing sweep is the correct
fix — run several semantically distinct queries and compare KEEP counts across them.
If only one framing surfaces KEEP rows, that framing is the hypothesis, not the
reality. The Frame artifact should require at least 3 framings before a Gather run.

---

## Anti-pattern 3: Loud Minority / Vocal Outlier

**What it is:** A small number of highly vocal posters dominate the corpus. On Upwork,
a client with $400k in spend and 100% hire rate will pattern-match as "dominant demand"
even if they are one unusual buyer.

**Concrete example:** The opportunity brief appendix shows one $448k client (GHL +
Zapier architect). That client alone could drive the KEEP verdict for a cluster.
Remove them and the signal may thin significantly.

**Structural fix:** The Score stage should flag any row where a single client's spend
is >30% of the total "strong tier" spend in a cluster. Flag as "outlier risk." The
verdict for that cluster should downgrade to WATCH unless 3+ independent strong clients
appear. This is the "n is small" discipline from the opportunity brief operationalized.

Sources: CIO.com on vocal minority; TruRating on extreme reviewers.
https://www.cio.com/article/197504/don-t-get-misled-by-the-vocal-minority.html

---

## Anti-pattern 4: Confirmation Bias Loop

**What it is:** The LLM relevance judge is prompted with examples and a query from the
same framing the founder already believes. It finds the framing it was given. The
pipeline loops: your Frame primes the relevance judge, the relevance judge confirms
your Frame.

**Concrete example:** `RELEVANCE_SYSTEM` in `discover_score.py` contains the example:
"EAM consulting is adjacent to ERP reporting." That's a real adjacency — but it also
demonstrates that the model's adjacency judgments can be seeded by examples. If the
system prompt contains framing artifacts, the relevance scores will reflect them.

**Structural fix:** Run the relevance stage on a random 10-record sample with and
without examples in the system prompt. If scores change by more than ±0.2 on average,
the examples are contaminating the judgment. Remove them and use a calibration file
instead.

Sources: LinkedIn Advice on confirmation bias in customer discovery; Mind the Product
on discovery pitfalls. https://www.mindtheproduct.com/common-product-discovery-pitfalls-and-how-to-avoid-them/

---

## Anti-pattern 5: Validation Theater

**What it is:** Running the pipeline produces an artifact that looks like validated
demand (a Board with KEEP rows) but is actually a sophisticated version of "I feel
good about this idea." The structure of the output creates false confidence.

**Concrete example:** A pipeline run on 20 records with 3 KEEP rows and a nicely
formatted board looks like validated demand. But 20 records is too small for any
statistical claim; 3 KEEPs could be noise. The board format implies more rigor than
the data supports.

**Structural fix:** The Board should include a "corpus health" header before any KEEP
rows:
- Total records gathered: N
- Records with client stats: N
- Records passing money gate: N (%)
- Distinct clients in KEEP tier: N

If N < 50 or distinct clients < 5, display a "thin corpus" warning that prevents the
KEEP rows from being treated as final. This is the Amy Hoy "skin in the game" principle
applied to the pipeline itself.

Sources: CoffeeSpace on validation theater.
https://www.coffeespace.com/blog-post/validation-theater-why-startup-founders-fool-themselves-with-fake-traction

---

## Anti-pattern 6: Services Demand ≠ Product Demand

**What it is:** Every data point in the Upwork pipeline is someone hiring a human
specialist. That proves the pain exists and recurs. It does NOT prove anyone would pay
for software to solve it instead.

**Concrete example:** Opportunity brief §1: "Services demand ≠ product demand. Every
data point is someone hiring a human specialist." This is the single biggest gap
between "promising Board output" and "validated business."

**Structural fix:** This cannot be resolved by the pipeline alone. The Red-team stage
should flag every KEEP row with the question: "Is this pain productizable, or does it
require human judgment that software cannot replace?" The kill argument on every
KEEP row should include a one-sentence answer. If the answer is "requires human
judgment," the row is WATCH, not KEEP, regardless of money signal strength.

This is a fundamental architectural addition: the Board's KEEP category should split
into KEEP-PRODUCTIZABLE and KEEP-SERVICE-ONLY.
