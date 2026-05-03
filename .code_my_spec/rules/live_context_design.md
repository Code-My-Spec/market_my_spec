---
component_type: "live_context"
session_type: "design"
---

# Phoenix Live Context Design Rules

## Naming Convention
- Use `AppWeb.{Feature}Live` as the namespace (e.g., `MyAppWeb.UserLive`)
- Child LiveViews use action suffixes: `UserLive.Index`, `UserLive.Show`, `UserLive.Edit`
- Child LiveComponents use descriptive names: `UserLive.FormComponent`, `UserLive.FilterComponent`

## Structure
- Each child LiveView corresponds to a unique route
- LiveComponents are shared across views in this context
- The live context itself has no code file — it is a spec-only grouping

## Scope
- Focus on a single feature area (users, accounts, orders)
- Keep the number of children manageable (typically 2-5 views + 0-3 shared components)
- Dependencies should point to domain contexts, not other live contexts
