# Start A Marketing Strategy Interview

As a solo founder with the Market My Spec MCP installed in Claude Code, I want to start a marketing strategy interview from a fresh session by invoking the skill, so the agent walks me through the 8-step flow and produces strategy artifacts in my project's local marketing/ directory.

## Meta
- id: c25d8f08-3200-4bf3-bab3-29ed495461a6
- number: 674
- status: in_progress
- priority: 1
- component: MarketMySpec.Skills.MarketingStrategy
- personas: founder

## Rules

### Invocation: the user runs the `/marketing-strategy` slash command (defined in the MMS Claude Code plugin) which causes the agent to call `invoke_skill("marketing-strategy")` against the MMS MCP server with its bearer token. The agent receives the SKILL.md body and treats it as the working playbook. The slash command accepts an optional argument-hint (e.g., "start from step 3", "just redo positioning") which is conveyed to the agent as user intent and may bypass Step 0 orient or jump to a specific step.

#### happy: User runs /marketing-strategy and the agent loads the playbook [5426d625]
Given a user with the MMS plugin installed and a valid bearer token in a fresh Claude Code session
When they type "/marketing-strategy" with no argument
Then the plugin (or agent) calls `invoke_skill` with `{"skill_name": "marketing-strategy"}` over the MCP transport
And the SKILL.md body is returned
And the agent reads it as its working playbook for this session
And the next thing the agent does is execute Step 0 (orient), not Step 1 questions

#### failure: Slash command invocation without bearer fails clearly [b97c6c67]
Given a user runs "/marketing-strategy" but their MMS bearer is missing or expired
When the agent calls `invoke_skill` over MCP
Then MMS returns 401 with WWW-Authenticate pointing at /.well-known/oauth-authorization-server
And the agent surfaces a "you need to sign in" message and walks the user through re-auth
And the agent does not proceed with the interview using a fabricated playbook

### Step 0 (Orient): before asking any interview questions, the agent does three things in parallel — (a) checks whether `./marketing/` exists in the user's CWD and lists its contents to detect iteration mode, (b) skims project context signals (README.md, package.json, mix.exs, Gemfile, a landing-page HTML, GBP — whatever signals the business type), (c) if the user passed a URL or product name in the argument-hint, fetches it via WebFetch first. Only after this orientation does the agent greet briefly and confirm intent.

#### happy: Agent skims project context before asking the first question [a3eddc4b]
Given a user runs "/marketing-strategy https://granitecountertopinstaller.example" in a CWD with a README.md and an index.html
When the agent enters Step 0 (orient)
Then it issues parallel reads/fetches: lists `./marketing/` contents (or notes absent), reads README.md and index.html, and WebFetches the supplied URL
And only after these complete does it issue a greeting like "I see you run a granite countertop install business — want me to walk all 8 steps or jump in somewhere?"
And it has not asked any interview questions yet

#### failure: Skipping orient and asking interview questions cold is rejected [6edcbe7c]
Given a transcript shows the agent's first non-tool-call message is "What's your business about?" with no prior LS / Read / WebFetch tool calls
When QA inspects the transcript against this rule
Then the run is flagged as out-of-protocol — the agent must orient before interviewing
And the SKILL.md text or step prompts are revised to make the parallel-orient instruction more emphatic if multiple agents skip it

### Industry-agnostic + cadence: the skill works for any business type (software product, consultant/services, trades, local business). The agent does not default to SaaS or dev-tool examples unless the user's business actually is one — examples are drawn from the user's industry. Interview cadence is one or two questions at a time, never a dump. The agent uses what the user already has (website, reviews, about page) before asking about it.

#### happy: Restaurant owner gets restaurant examples and one-question cadence [376d16fe]
Given the user is opening a restaurant and runs the skill
When the agent reaches step 2 (jobs and segments) and asks for ICP refinement
Then each agent turn asks at most two questions
And the examples it offers ("dinner-party hosts", "weekday lunch crowd", "occasion diners") are drawn from restaurant context — not "developer evaluating dev tools" or any SaaS framing
And before asking about menu / hours / location, the agent has already read whatever the user gave it (Google Business Profile, existing site)

#### failure: SaaS-default examples for a non-SaaS user are rejected [5bfa4d24]
Given the user runs the skill for a granite countertop install business
When the agent's step 2 question dump uses examples like "monthly active users", "trial conversion rate", "self-serve onboarding"
When QA inspects the transcript
Then the run is flagged — the examples are wrong category for trades
And the SKILL.md or step prompt language is reinforced to keep the agent from defaulting to SaaS framing
And the dump-of-six-questions format is also flagged separately as a cadence violation

### Write-as-you-go per step: at the end of each step, the agent writes that step's artifact to `./marketing/NN_<slug>.md` (matching the steps/ filenames) using its own Write tool, before advancing to the next step. No batching — if the user bails after step 3, they retain three usable files. In iteration mode (./marketing/ already exists), the agent updates files in place and appends a `## Revision — YYYY-MM-DD` section noting what changed and why.

#### happy: User bails after step 3 and finds three usable artifacts on disk [ddab76f5]
Given a user has completed steps 1, 2, and 3 of the interview, and then closes Claude Code
When they look in their working directory
Then `./marketing/01_current_state.md`, `./marketing/02_jobs_and_segments.md`, `./marketing/03_personas.md` all exist with non-empty content
And `./marketing/research/` exists with the supporting persona research
And no step was deferred or "saved at the end" — each artifact was written immediately when its step concluded

#### failure: Batched end-of-run artifact writes are rejected [6d738203]
Given a transcript shows the agent ran through all 8 step interviews in sequence, then issued 8 Write tool calls back-to-back at the end
When QA inspects the transcript
Then the run is flagged — if the user had quit at step 5 nothing would have been saved
And the SKILL.md / step prompts are reinforced with explicit "write before advancing to the next step" wording at the end of each step file

### Step 3 (Persona research) dispatches research subagents for evidence — invented personas are worse than no personas. The agent does not skip step 3, does not synthesize personas from prior interview answers alone, and does not run interview-only persona generation. The output of step 3 lands at `./marketing/03_personas.md` with supporting research at `./marketing/research/`.

#### happy: Step 3 dispatches research subagents and grounds personas in evidence [5e3119b9]
Given the agent completes step 2 and proceeds to step 3
When it reads `steps/03_persona_research.md` via `read_skill_file`
Then it dispatches at least one research subagent (Agent tool with subagent_type=researcher or similar) per persona candidate
And each subagent's output lands as a file in `./marketing/research/<topic>.md`
And `./marketing/03_personas.md` is synthesized from the research outputs (not from interview answers alone)
And every persona claim in 03_personas.md cites a research artifact in `research/`

#### failure: Persona file with no supporting research artifacts is rejected [726f3781]
Given a run produces `./marketing/03_personas.md` with three personas
When QA inspects the file and the working directory
Then `./marketing/research/` does not exist or is empty
And no Agent tool calls appear in the transcript for step 3
And the run is flagged as out-of-protocol — personas are invented, not researched
And the agent is required to re-run step 3 with research subagent dispatch before proceeding

### Scope guardrails: the skill explicitly does NOT write finished blog posts, ads, landing pages, or emails (downstream content work); does NOT set up analytics, CRMs, email tools, or ad accounts (tooling setup); does NOT produce a 40-slide marketing plan deck (this is a working strategy, not a board doc); does NOT do ongoing content scanning. When the user requests one of these, the agent acknowledges and declines, pointing them at the appropriate downstream skill or workflow.

#### happy: User asks for a blog post and the agent deflects to downstream content [b9dab04e]
Given the user is mid-interview at step 7 (channels) and says "OK, write me a blog post for the channel mix"
When the agent processes the request
Then it acknowledges and declines: "Strategy doc only here — once we lock in the channels in step 8, run the content skill against this strategy to generate posts"
And it stays on the strategy track, completing step 7 and proceeding to step 8 instead of context-switching to content production
And no `./marketing/blog/` or similar content artifact is written

#### failure: Agent silently produces a 40-slide deck or sets up analytics is rejected [982db2e3]
Given the user asks the agent for "a slide deck I can present to investors" or "set up GA4 for me"
When the agent obliges by writing a slides.md or executing a Bash command to install analytics tooling
When QA inspects the run
Then it is flagged as out-of-scope — the skill builds working strategy, not decks or tooling
And the agent's handling is corrected: acknowledge, decline, point at the right tool / workflow
