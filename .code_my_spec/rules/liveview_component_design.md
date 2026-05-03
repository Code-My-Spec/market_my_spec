---
component_type: "liveview_component"
session_type: "design"
---

# Phoenix LiveComponent Design Rules

## Design System

Before building any UI, read `.code_my_spec/design/design_system.html` for the project's design system. Use the DaisyUI component classes and theme tokens defined there. Do not invent custom colors or component patterns that deviate from the design system.

## Assigns
- Always include `:id` assign (required by LiveComponent)
- Document all assigns in a table: Assign, Type, Required, Description
- Use typed assigns (`User.t()`, `Changeset.t()`) for clarity

## Events
- Use `phx-target={@myself}` to scope events to this component
- Communicate with parent views via `send(self(), {:event_name, data})`
- Keep event handling local — don't reach into parent assigns

## File Structure
- Place in `lib/my_app_web/live/{context}_live/` alongside sibling views
- Name files by purpose: `form_component.ex`, `filter_component.ex`

## Required Spec Sections

1. **Assigns** - Table of all assigns with types and required flag
2. **Design** - Layout structure, DaisyUI components, responsive behavior
3. **Events** (optional) - handle_event callbacks with phx-target={@myself}
4. **Dependencies** (optional) - Domain contexts this component calls

## Style Guidelines

- **Be concise** - Each section should be brief but complete
- **Use bullets** - Structure information as bullet points
- **Include context calls** - Show exactly which context functions are used
- **Show code examples** - Provide HEEx usage examples for components
- **Focus on behavior** - Describe what happens, not how it's implemented
- **Consider security** - Always include permission and authorization concerns
- **Plan for real-time** - Consider PubSub integration for live updates
