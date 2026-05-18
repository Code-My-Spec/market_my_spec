# Dev Story: Reproducible Prompts

This document records the exact prompts and process used to generate the dev story narrative from git history. You can re-run this process anytime to regenerate the story.

## Overview

- **Source**: 584 commits from Jul 2025 - Mar 2026
- **Method**: Extract git log by month, summarize each month in parallel, synthesize into full narrative
- **Tools**: Claude Code with parallel subagents

## Step 1: Extract Monthly Chunks

```bash
# Create directory structure
mkdir -p .code_my_spec/campaigns/dev_story/{chunks,summaries}

# Extract git log by month
for year_month in "2025-07" "2025-08" "2025-09" "2025-10" "2025-11" "2025-12" "2026-01" "2026-02" "2026-03"; do
  y="${year_month:0:4}"
  m="${year_month:5:2}"
  next_m=$((10#$m + 1))
  next_y=$y
  if [ $next_m -gt 12 ]; then
    next_m=1
    next_y=$((y + 1))
  fi
  next_month=$(printf "%04d-%02d" $next_y $next_m)

  count=$(git log --oneline --since="${year_month}-01" --until="${next_month}-01" | wc -l | tr -d ' ')

  {
    echo "# Git Log: ${year_month}"
    echo ""
    echo "Commits: ${count}"
    echo ""
    git log --since="${year_month}-01" --until="${next_month}-01" \
      --format="## %h - %s%n%nDate: %ai%nAuthor: %an%n" --stat
  } > ".code_my_spec/campaigns/dev_story/chunks/${year_month}.md"
done
```

**Output**: 9 files in `chunks/` (one per month), totaling ~9,800 lines.

## Step 2: Summarize Each Month (Parallel Subagents)

Spawn 9 parallel `general-purpose` subagents, one per chunk file. Each receives this prompt (with `{YEAR_MONTH}` and `{WORD_RANGE}` substituted):

```
Read the file `.code_my_spec/campaigns/dev_story/chunks/{YEAR_MONTH}.md`
which contains the git log for {MONTH_LABEL} of the CodeMySpec project.

Write a narrative summary of this month's development work. The summary should:
- Be written in an engaging, storytelling style (third person, past tense)
- Highlight the key themes, features built, and architectural decisions
- Group related commits into coherent storylines
- Note the pace and momentum of development
- Be {WORD_RANGE} words
- Use markdown with a month heading

Write the summary to `.code_my_spec/campaigns/dev_story/summaries/{YEAR_MONTH}.md`
```

**Word ranges**: 300-600 for full months, 200-400 for partial months (2026-03).

**Output**: 9 summary files in `summaries/`.

## Step 3: Synthesize Full Narrative

Spawn one `general-purpose` subagent that reads all 9 summaries and produces the final story:

```
You are writing the development story of CodeMySpec, an Elixir/Phoenix application
that helps developers use AI agents to build software from specifications.

Read all 9 monthly summary files in
`.code_my_spec/campaigns/dev_story/summaries/` (2025-07 through 2026-03).

Write a compelling, cohesive development narrative that:
- Opens with a brief introduction to what CodeMySpec is and the 8-month journey
  (584 commits, Jul 2025 - Mar 2026)
- Weaves the monthly summaries into a continuous story with clear narrative arcs
- Identifies 3-5 major phases/turning points in the project's evolution
- Highlights the most significant architectural decisions and their impact
- Notes the human-AI collaboration aspect (Claude Code as a development partner)
- Closes with where the project stands now and its trajectory
- Is 1500-2500 words
- Uses markdown with clear section headings
- Reads like a dev blog post / project retrospective

Write the full narrative to
`.code_my_spec/campaigns/dev_story/synthesis.md`
```

**Output**: `synthesis.md` - the full project story.
