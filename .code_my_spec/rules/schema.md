---
component_type: "schema"
session_type: "code"
---

- Don't specify the type of primary or foreign keys unless absolutely necessary.
- Write typespecs for all ecto schemas.
- Use `Ecto.Enum`.
- Include typespecs in schemas
- Include defaults for non-required fields: `default: value`
- Always specify enum defaults
- Include appropriate validations in changeset function
- Use `validate_required/2` for required fields
- Add length, format, and constraint validations as needed
- Create private validation functions for complex logic
- Use `belongs_to` and `has_many` for related data when coupling is desired