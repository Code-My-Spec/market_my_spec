---
component_type: "liveview_form"
session_type: "code"
---
## Phoenix 1.8 Form Component Pattern

**Structure**: Create a single LiveView module handling both `:new` and `:edit` actions with these required elements:

1. **Module Setup**
   ```elixir
   defmodule AppWeb.ResourceLive.Form do
     use AppWeb, :live_view
     alias App.Context
     alias App.Context.Schema
   ```

2. **Required Functions**
   - `render/1` - Form template with `phx-change="validate"` and `phx-submit="save"`
   - `mount/3` - Extract `return_to` param and call `apply_action/3`
   - `apply_action/3` - Pattern match on `:new`/`:edit`, set page title, schema, and form
   - `handle_event/3` - Handle "validate" and "save" events
   - `save_resource/3` - Pattern match on action, call context create/update functions

3. **Key Patterns**
   - Use `to_form(changeset)` for form assignment
   - Handle validation with `action: :validate` on changeset errors
   - Navigate on success with `push_navigate/2`
   - Support `return_to` parameter for flexible navigation
   - Use consistent flash messages: "Resource created/updated successfully"

4. **Template Requirements**
   - Wrap in layout component with flash and current_scope
   - Include header with dynamic page title
   - Form with proper field inputs and submit/cancel buttons
   - Cancel button navigates to computed return path

This pattern ensures consistent CRUD form behavior across your Phoenix 1.8 application.