# Sources — MCP Agent

All sources accessed 2026-05-03 unless noted. Grouped by evidence cluster.

## E1 — Claude Code file-tool design and read-before-edit invariant

- https://code.claude.com/docs/en/overview — "Claude Code overview" (Anthropic primary docs) — accessed 2026-05-03
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/text-editor-tool — "Text editor tool" (Claude API docs — read/write/edit primitives via API) — accessed 2026-05-03
- https://www.markdown.engineering/learn-claude-code/18-file-tools/ — "Lesson 18 — File Tools: Read, Write, Edit — Source Deep Dive" (mdENG, third-party reverse-engineering of Claude Code's file tool implementation) — accessed 2026-05-03
- https://callsphere.ai/blog/claude-code-tool-system-explained — "Claude Code's Tool System: Read, Write, Bash, Glob, Grep Explained" (CallSphere) — accessed 2026-05-03
- https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude — "Create and edit files with Claude" (Anthropic Help Center) — accessed 2026-05-03
- https://claudefa.st/blog/guide/changelog — "Claude Code Changelog: All Release Notes (2026)" (changelog tracker — references the March 2026 truncation incident #21841 showing 25K-token vs 100-byte cost) — accessed 2026-05-03
- https://claudelog.com/faqs/claude-code-error-editing-file/ — "Claude Code Error Editing File: Causes & Fixes" (ClaudeLog — common Edit failure modes from real usage) — accessed 2026-05-03
- https://claude.com/product/claude-code — "Claude Code by Anthropic" (Anthropic primary product page) — accessed 2026-05-03

## E2 — MCP adoption and reference-implementation status

- https://modelcontextprotocol.io/ — "What is the Model Context Protocol (MCP)?" (Anthropic / MCP primary site) — accessed 2026-05-03
- https://en.wikipedia.org/wiki/Model_Context_Protocol — "Model Context Protocol" (Wikipedia, cross-references native client adoption across Claude, ChatGPT, Cursor, Windsurf, Zed, JetBrains, Vercel AI SDK, OpenAI Agents SDK) — accessed 2026-05-03
- https://www.digitalapplied.com/blog/mcp-adoption-statistics-2026-model-context-protocol — "MCP Adoption Statistics 2026: Model Context Protocol" (Digital Applied — 7.8x server registry growth, 78% enterprise AI teams, 4.2h vs 18h integration time) — accessed 2026-05-03
- https://anandtopu.medium.com/the-future-of-mcp-how-agents-get-connected-in-2026-ee24d62c0c43 — "The Future of MCP: How Agents Get Connected in 2026" (Anand Topu, Medium — Anthropic-led → industry-default transition between July 2025 and Feb 2026) — accessed 2026-05-03
- https://dev.to/pooyagolchian/mcp-in-2026-the-protocol-that-replaced-every-ai-tool-integration-1ipc — "MCP in 2026: The Protocol That Replaced Every AI Tool Integration" (DEV Community) — accessed 2026-05-03
- https://pooya.blog/blog/mcp-model-context-protocol-production-2026/ — "MCP Protocol 2026: Build Production Servers for Claude, Cursor, VS Code Copilot" (Pooya Golchian, production-server perspective) — accessed 2026-05-03
- https://truto.one/blog/what-is-mcp-model-context-protocol-the-2026-guide-for-saas-pms — "What is MCP (Model Context Protocol)? The 2026 Guide for SaaS PMs" (Truto — SaaS PM lens on MCP) — accessed 2026-05-03

## E3 — Heterogeneous agent fleet and multi-tool stacks

- https://www.morphllm.com/best-ai-coding-agents-2026 — "14 Best AI Coding Agents in 2026: Ranked by Benchmarks and Real Usage" (Morphllm — 14-tool roundup, benchmark + share data) — accessed 2026-05-03
- https://www.morphllm.com/comparisons/morph-vs-aider-diff — "Aider Uses 4.2x Fewer Tokens Than Claude Code (2026): 3-Tool Benchmark on 47 Files" (Morphllm — Aider 126K avg tokens, Claude Code 200K context, real workload comparison) — accessed 2026-05-03
- https://www.morphllm.com/ai-coding-agent — "We Tested 15 AI Coding Agents (2026). Only 3 Changed How We Ship." (Morphllm — qualitative agent rankings) — accessed 2026-05-03
- https://thoughts.jock.pl/p/ai-coding-harness-agents-2026 — "Claude Code vs Codex CLI vs Aider vs OpenCode vs Pi vs Cursor: Which AI Coding Harness Actually Works Without You?" (jock.pl — harness-engineering lens) — accessed 2026-05-03
- https://codersera.com/blog/ai-coding-agents-complete-guide-2026/ — "AI Coding Agents in 2026: Cursor vs Claude Code vs Cline vs Aider vs Windsurf" (Codersera) — accessed 2026-05-03
- https://newsletter.pragmaticengineer.com/p/ai-tooling-2026 — "AI Tooling for Software Engineers in 2026" (Pragmatic Engineer — 70% use 2-4 tools, 15% use 5+, Claude Code 46% loved-most, Cursor 19%, Copilot 9%, Cursor 1M+ devs / 360K paid / 64% F500) — accessed 2026-05-03
- https://www.builder.io/blog/cursor-vs-claude-code — "Claude Code vs Cursor: What to Choose in 2026" (Builder.io) — accessed 2026-05-03
- https://www.cosmicjs.com/blog/claude-code-vs-github-copilot-vs-cursor-which-ai-coding-agent-should-you-use-2026 — "Claude Code vs GitHub Copilot vs Cursor (2026): Honest Comparison" (Cosmic JS) — accessed 2026-05-03
- https://www.digitalapplied.com/blog/ai-coding-agents-claude-code-cursor-codex-replit-2026 — "AI Coding Agents: Claude Code vs Cursor vs Codex 2026" (Digital Applied) — accessed 2026-05-03

## E4 — Agentic workflow mainstreaming and multi-file edits

- https://newsletter.pragmaticengineer.com/p/ai-tooling-2026 — "AI Tooling for Software Engineers in 2026" (Pragmatic Engineer — 55% regular agent usage, 63.5% staff+ engineer adoption) — accessed 2026-05-03
- https://www.qodo.ai/blog/best-ai-coding-assistant-tools/ — "Top 15 AI Coding Assistant Tools to Try in 2026" (Qodo — multi-file edit and agent-driven workflow coverage) — accessed 2026-05-03
- https://www.augmentcode.com/tools/13-best-ai-coding-tools-for-complex-codebases — "13 Best AI Coding Tools for Complex Codebases in 2026" (Augment Code — repo-scale agent workflows) — accessed 2026-05-03
- https://github.com/zilliztech/claude-context — "Code search MCP for Claude Code" (Zilliz — ecosystem example of MCP-server-augmented agent workflows) — accessed 2026-05-03

## E5 — Context efficiency and tool-shape impact on first-call success

- https://www.morphllm.com/comparisons/morph-vs-aider-diff — "Aider Uses 4.2x Fewer Tokens Than Claude Code (2026)" (Morphllm — token-per-task comparisons across tools) — accessed 2026-05-03
- https://claudefa.st/blog/guide/changelog — "Claude Code Changelog: All Release Notes (2026)" (truncation #21841 — 25K-token responses vs 100-byte error throw) — accessed 2026-05-03
- https://www.markdown.engineering/learn-claude-code/18-file-tools/ — "Lesson 18 — File Tools: Read, Write, Edit — Source Deep Dive" (mdENG — implementation rationale for the read-before-edit invariant and dedup) — accessed 2026-05-03
