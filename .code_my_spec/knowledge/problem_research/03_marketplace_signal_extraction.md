# Marketplace and Job-Board Signal Extraction

## Executive summary

Freelance marketplaces (Upwork, Fiverr, Freelancer) expose demonstrated paying demand
in a form no survey can replicate: a client has opened a wallet. The pipeline's Upwork
adapter is the right first channel because Upwork's client stats (totalSpent, hireRate)
provide a money gate that raw job-board data does not. Other signal classes — GitHub
Issues, HN "Ask HN" threads, Reddit "looking for" posts, review sites — exist but are
lower on the hierarchy because they show pain without cash transfer.

---

## The signal class hierarchy

Rank these by fidelity to "someone is paying right now":

| Signal class | Example | Money evidence | Noise risk |
|---|---|---|---|
| Freelance marketplace (client stats) | Upwork with totalSpent | Direct (real payments) | Low (gated by hireRate) |
| Freelance marketplace (no client stats) | Fiverr buyer requests | Indirect | Medium |
| Job boards (corporate hiring) | LinkedIn, Indeed | Salary budget stated | Medium |
| Review sites | G2, Trustpilot, Capterra complaints | None (pain only) | High |
| Community complaints | Reddit, HN, Discord | None | High |
| GitHub Issues (missing library) | "please add X integration" | None | Very high |

---

## Canonical sources

### Upwork as a demand signal — the pipeline's current approach

The broken_oaths pipeline's insight is correct and not widely documented: Upwork's
`totalSpent` (lifetime client spend) + `hireRate` (the fraction of their posts that
resulted in a hire) is a better money gate than the job budget, which is garbage
(most clients post $0 or $5-30/hr as a placeholder). A client who has spent $100k on
Upwork and hires 80% of people they post for is a _demonstrated_ buyer — not a
tire-kicker exploring options.

This observation is the core of the pipeline's axis 1. It is not documented in any
mainstream market-research literature; it is empirical from the bakeoff.

### Fiverr / Freelancer / PeoplePerHour as additional channels

These platforms have weaker client-side stats than Upwork. Fiverr Buyer Requests (now
deprecated as a public API surface) showed demand but not spend history. Freelancer.com
and PeoplePerHour have similar limitations. Useful for triangulation, not primary
gating.

Note: Browse.ai and Apify both have Fiverr and Freelancer scrapers. Quality is
comparable to Upwork, but data depth (client history) is lower.

### LinkedIn Job Postings — hiring as a proxy for pain

When a company posts a role that specifically describes a pain ("We need someone to
migrate 200 client accounts from HubSpot to GHL"), that is a demonstrated willingness
to pay _salary_ for the capability. Salary spend is a strong signal; it implies the
pain recurs at a volume that justifies headcount. LinkedIn Jobs API exists (restricted
but accessible via Apify).

The JobSpy library (open source, 2024) scrapes LinkedIn, Indeed, Glassdoor, ZipRecruiter
concurrently. https://github.com/speedyapply/JobSpy

### GitHub Issues — "please build X" as demand signal

GitHub Issues filed against library gaps ("support X platform," "add Y integration")
show demand from developers. These are useful for _tooling_ markets but weak for
business-problem markets. The signal is: a developer was frustrated enough to file a
public complaint. That is pain-exists evidence, not paid-demand evidence.

### HN "Ask HN" and Reddit "looking for" threads

"Ask HN: Has anyone built X?" and Reddit posts saying "Looking for a tool that does Y"
are low-fidelity demand signals. They prove the pain exists and is discussable, but
they have no money gate. They are useful as Frame-stage vocabulary sources — the
language people use to describe the pain — not as Score-stage evidence.

A tool called Request Hunt (HN, 2025) aggregates feature requests from Reddit, GitHub,
and X into a searchable database. Useful for Gather vocabulary, not for gating.
https://news.ycombinator.com/item?id=46352696

### Review Sites (G2, Capterra, Trustpilot)

Negative reviews of incumbents are pain-signal mines. "I left [product X] because it
couldn't do [Y]" is a JTBD switch-event in natural language. These are high-value Frame
inputs. But they do not constitute money evidence — the reviewer switched, which means
they _were_ paying, but you can't see how much or how often.

---

## Mapping to the 5-stage pipeline

**Gather stage — adapter strategy**

The current Gather adapter is `upwork-vibe~upwork-job-scraper` via Apify. The
`NormalizedRecord` contract already abstracts the adapter, which means adding new
sources requires only a new `map_*` function. Priority order for next adapters:

1. LinkedIn job postings (via JobSpy or Apify actor) — hires a salary proxy for pain
2. Fiverr buyer requests (Apify, weaker client stats)
3. G2/Capterra negative reviews (Frame input, not Score input — no money gate possible)
4. Reddit "looking for" threads (Frame vocabulary only)

**Score stage — adapter-specific money gate**

Each adapter needs its own money gate because the field names differ:
- Upwork: `totalSpent` × `hireRate`
- LinkedIn jobs: `salary_range_max` × `seniority_level` (Staff-level hire = $200k+
  salary = demonstrated pain budget)
- G2: no money gate possible → drop to `WATCH` floor regardless of relevance

**Frame stage — vocabulary from low-fidelity sources**

Reddit and HN threads are inputs to the Frame query, not Score evidence. The Frame
artifact should include a "vocabulary audit" step: read 10 community posts to extract
the exact words the market uses, then encode those as the Gather query terms.

---

## Where our intent doc is silent / contradictory

- The intent doc says "Upwork today; Reddit, review sites, job boards next" but treats
  them as equivalent future sources. They are not equivalent — they sit at different
  points on the money-signal hierarchy. A future Gather adapter for Reddit should feed
  Frame vocabulary, not Score evidence.

- The pipeline has no concept of "signal class" — a metadata tag on each record
  indicating whether it carries a money gate or is pain-only. Adding `signal_class`
  to `NormalizedRecord` would let the Score stage apply adapter-appropriate logic
  rather than failing silently on records that have no client stats.
