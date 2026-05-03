---
component_type: "context"
session_type: "design"
---

# Phoenix Context Design Rules

## Scope-First Security
- All public functions must accept a scope struct as the first parameter
- Database queries must filter by scope foreign keys (user_id, org_id, etc.)

## API Design
- Functions should be self-documenting through clear naming
- Return consistent error tuples across the context
- Group related operations logically
- Maintain scope parameter consistency across all functions
