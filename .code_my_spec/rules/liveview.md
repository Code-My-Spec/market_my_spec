---
component_type: "liveview"
session_type: "code"
---

# LiveView Coding Rules

## Design System

Read `.code_my_spec/design/design_system.html` for the project's design system before writing any templates. Use the DaisyUI component classes and theme tokens defined there. Do not invent custom colors or component patterns that deviate from the design system.

## General

When possible, include both the markup and the functions in a single .ex file, not split between an .ex file and a .html.heex file. The render function should be at the top.

## Component Hierarchy (use in this order)

### 1. Project core_components.ex (first choice)
Use the function components defined in the project's `core_components.ex`. These include:
`<.button>`, `<.input>`, `<.flash>`, `<.table>`, `<.header>`, `<.modal>`, `<.list>`, `<.icon>`, `<.back>`, `<.simple_form>`, `<.error>`, `<.label>`.
Read core_components.ex to discover the full set before implementing.

### 2. DaisyUI component classes (second choice)
When core_components doesn't cover a pattern, use DaisyUI semantic classes.
Common components to reach for:
- Layout: `card`, `drawer`, `navbar`, `footer`, `hero`, `divider`
- Navigation: `menu`, `tabs`, `breadcrumbs`, `steps`, `bottom-navigation`
- Data display: `stat`, `table`, `badge`, `kbd`, `countdown`, `diff`
- Feedback: `alert`, `toast`, `loading`, `skeleton`, `progress`
- Actions: `dropdown`, `swap`, `theme-controller`
- Overlay: `modal`, `tooltip`

Example — prefer DaisyUI:
```heex
<%!-- Good: DaisyUI card --%>
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title"><%= @title %></h2>
    <p><%= @description %></p>
    <div class="card-actions justify-end">
      <.button>Learn More</.button>
    </div>
  </div>
</div>

<%!-- Bad: raw Tailwind rebuilding a card from scratch --%>
<div class="rounded-lg bg-white p-6 shadow-lg">
  <h2 class="text-xl font-bold"><%= @title %></h2>
  <p class="mt-2 text-gray-600"><%= @description %></p>
  <div class="mt-4 flex justify-end">
    <.button>Learn More</.button>
  </div>
</div>
```

### 3. Raw Tailwind utility classes (last resort)
Only use raw Tailwind classes for fine-grained adjustments that DaisyUI doesn't cover, such as custom spacing, positioning, or one-off visual tweaks.