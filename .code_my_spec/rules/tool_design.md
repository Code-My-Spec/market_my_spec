---
component_type: "mcp_tool"
session_type: "design"
---

# MCP Tool Design Rules

Follow these principles when designing MCP tools:

## Core Structure

### Module Pattern
- Use `Hermes.Server.Component` with `type: :tool`
- Include descriptive `@moduledoc` explaining the tool's purpose
- Alias necessary modules at the top (Stories, StoriesMapper, Validators)

### Schema Definition
- Define required and optional fields using `schema do` block
- Use appropriate field types (`:string`, `{:list, :string}`, `{:list, :map}`)
- Mark required fields explicitly with `required: true`

## Implementation Pattern

### Validation First
- Always validate scope using `Validators.validate_scope(frame)` as first step
- Use `with` pattern for chaining validations and operations
- Fail fast and let supervisors handle recovery

### Error Handling
- Pattern match on different error types in `else` clause
- Handle `%Ecto.Changeset{}` validation errors specifically when applicable
- Use a `Mapper` for consistent response formatting, which should be defined per context
- Map atom errors to user-friendly messages

### Response Formatting
- Always return `{:reply, response, frame}` tuple
- Use StoriesMapper functions for consistent response structure:
  - `x_response/1` for single operations
  - `x_batch_response/1` for successful batch operations
  - `validation_error/1` for changeset errors
  - `error/1` for general errors

## Specific Patterns

### Single Entity Operations (Create, Update, Delete)
```elixir
def execute(params, frame) do
  with {:ok, scope} <- Validators.validate_scope(frame),
       {:ok, entity} <- Context.operation(scope, params) do
    {:reply, Mapper.entity_response(entity), frame}
  else
    {:error, changeset = %Ecto.Changeset{}} ->
      {:reply, Mapper.validation_error(changeset), frame}
    
    {:error, atom} ->
      {:reply, Mapper.error(atom), frame}
  end
end
```

### Batch Operations
- Use `Enum.reduce/3` to accumulate successes and failures
- Track index for error reporting
- Return partial success with detailed failure information
- Reverse accumulated lists to maintain order

### Read Operations
- Use bang functions (`get_story!/2`) when entity must exist
- Let the function crash if entity not found (fail fast principle)

## Data Flow

### Input Processing
- Accept structured parameters through schema validation
- Transform data as needed before passing to context functions
- Use `Map.drop/2` to remove non-updatable fields (like `:id`)

### Output Processing  
- Always use mapper functions for response formatting
- Maintain consistent response structure across all tools
- Include relevant data and clear error messages

## Naming Conventions

### Module Names
- Follow pattern: `CodeMySpec.McpServers.{Domain}.Tools.{Action}{Entity}`
- Use descriptive action verbs (Create, Update, Delete, Start)
- Use singular entity names

### Function Names
- Use `execute/2` as the main entry point
- Use private helper functions for complex formatting
- Choose descriptive names that reveal intent

## Error Philosophy

### Clear Error Messages
- Provide actionable error information
- Use consistent error response format
- Map technical errors to user-friendly messages

## Testing Considerations

- Design tools to be easily testable without mocks
- Make dependencies explicit through function parameters
- Use pure functions for data transformations
- Keep side effects isolated in context layer