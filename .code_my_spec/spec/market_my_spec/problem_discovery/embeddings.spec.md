# MarketMySpec.ProblemDiscovery.Embeddings

OpenAI Embeddings client. Prefer ReqLLM if its embeddings coverage is clean, fall back to direct Req. App-level OPENAI_API_KEY via env config. Used by Gather to embed each JobPosting once on insert. See architecture/decisions/openai-embeddings.md and architecture/decisions/problem-discovery-data-sources.md.

## Type

module
