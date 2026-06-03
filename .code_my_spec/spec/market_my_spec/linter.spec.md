# MarketMySpec.Linter

Per-account prose linting. Owns the Linter behaviour (lint/2, validate_config/1) and Vale as the v1 implementation. Stores the per-account Vale `.vale.ini` text on the Account and shells out to the Vale CLI to validate configs at save time and lint polished prose at polish time. Returns alerts as a flat, agent-friendly shape (severity, check name, line, column, message). See ADR `.code_my_spec/architecture/decisions/vale.md` and knowledge `.code_my_spec/knowledge/vale-cli.md` for the runtime model.

## Type

context

## Dependencies

- MarketMySpec.Linter.Config
- MarketMySpec.Linter.ConfigsRepository
- MarketMySpec.Users.Scope
