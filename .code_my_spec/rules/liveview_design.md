---
component_type: "liveview"
session_type: "design"
---

# LiveView Design Documentation Rules

## Purpose
These rules ensure consistent, complete design documentation for Phoenix LiveViews and components before implementation.

## Design System

Before building any UI, read `.code_my_spec/design/design_system.html` for the project's design system. Use the DaisyUI component classes and theme tokens defined there. Do not invent custom colors or component patterns that deviate from the design system.

## Guidelines

Keep liveviews small and focused.
Each liveview should correspond to a path. No modifying the UI implicitly without a path change.

## LiveView Design Template

### File Structure
- Place in `docs/design/my_app_web/{context}_live/`
- Name files by function: `index.md`, `show.md`, `form.md`

### Required Sections

1. **Purpose** - Single sentence/short paragraph describing what this LiveView does
2. **Route** - The URL pattern that renders this LiveView
3. **Context Access** - List the context functions this LiveView calls
4. **LiveView Structure** - Three subsections:
   - **Mount** - What happens when LiveView initializes
   - **Events** - User interactions and their handlers
   - **Template** - UI structure and components used
5. **Data Flow** - Numbered steps of the user journey
6. **Security** - Permission checks and authorization rules
7. **Real-time Updates** - PubSub subscriptions and live updates (if applicable)

## Style Guidelines

- **Be concise** - Each section should be brief but complete
- **Use bullets** - Structure information as bullet points
- **Include context calls** - Show exactly which context functions are used
- **Show code examples** - Provide HEEx usage examples for components
- **Focus on behavior** - Describe what happens, not how it's implemented
- **Consider security** - Always include permission and authorization concerns
- **Plan for real-time** - Consider PubSub integration for live updates
