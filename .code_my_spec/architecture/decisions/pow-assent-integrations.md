# Use PowAssent and CodeMySpec generators for integrations, multi-tenancy, and feedback

## Status
Accepted (pre-made)

## Context
We need OAuth/third-party integrations, multi-tenant account isolation, and an embeddable feedback widget — all scaffolded consistently and wired into the standard stack.

## Decision
Use PowAssent (`pow_assent`) for OAuth provider integrations and the `code_my_spec_generators` package to scaffold the integration layer (`cms_gen.integrations`, `cms_gen.integration_provider`), multi-tenant accounts (`cms_gen.accounts`), and the feedback widget (`cms_gen.feedback_widget`). The generators produce code that lives in the project, keeping everything customizable while following CodeMySpec conventions.

## Consequences
This is a pre-made decision for the standard CodeMySpec stack.
