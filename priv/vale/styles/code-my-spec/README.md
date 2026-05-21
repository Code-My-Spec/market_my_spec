# code-my-spec Vale Style

Brand voice linter for CodeMySpec long-form prose. Encodes the John Davenport tone guide as Vale rules.

## Rules

| Rule | Severity | Catches |
|---|---|---|
| `EmDashes` | error | Em-dash characters and ` -- ` patterns. The tone guide forbids em-dashes (Reddit spam-filter trigger, AI tell). |
| `CorporateDiction` | error | leverage, unlock, revolutionize, master, ultimate, transformative, game-changing, empower, synergize, etc. |
| `AITells` | error | Phrases that read as LLM filler: delve into, in the realm of, navigate the landscape, embark on a journey, robust ecosystem, moreover, furthermore. |
| `LinkedInBro` | error | "In today's fast-paced world," "more than ever," "this changes everything," etc. |
| `Fillers` | warning | Filler transitions: "Let's explore," "Here's the thing," "It's worth noting," "In conclusion." |
| `Hedges` | warning | Hedging where directness is called for: "It could be argued," "Many people find," "Some prefer." |
| `StockMetaphors` | warning | Double-edged sword, low-hanging fruit, elephant in the room, tip of the iceberg, etc. |
| `SetupClauses` | warning | "At the end of the day," "When all is said and done," "The bottom line is." |
| `Emoji` | warning | Unicode emoji in prose. |
| `FirstPersonAbsent` | warning | Document-level: fewer than 3 first-person pronouns. John's voice is first-person. |

## Usage

```ini
StylesPath = /absolute/path/to/styles
Packages = write-good

[*.md]
BasedOnStyles = write-good, code-my-spec
```

Pair with `write-good` for general prose hygiene (passive voice, weasel words, wordiness). The `code-my-spec` rules cover brand-specific voice; `write-good` covers craft.

## Source

The rule contents are derived from `.code_my_spec/knowledge/tone-guide.md`. When the tone guide updates, the rules should be re-audited.
