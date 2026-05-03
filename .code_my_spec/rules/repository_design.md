---
component_type: "repository"
session_type: "design"
---

# Repository Design Documentation Rules

## Document Structure

### Required Sections (in order)
1. **Purpose** - Single paragraph explaining repository role
2. **Core Operations/Public API** - Functions grouped by category with `@spec` signatures. ONLY write specs for public functions.
3. **Function Descriptions** - Key function explanations
4. **Error Handling** - Standard error patterns
5. **Usage Patterns** - Integration with other layers

### Optional Sections
- **Transaction Patterns** - Complex multi-step operations
- **Query Composition** - Chainable query examples
- **Performance Considerations** - Optimization notes
- **Dependencies** - External libraries/schemas

## Function Organization

### Grouping Categories
- **Basic CRUD** - create, get, update, delete, list
- **Query Builders** - filtering/search (prefix with `by_`, `with_`, `search_`)
- **Status Management** - state transitions
- **Specialized Operations** - domain-specific functions

### Naming Conventions
- Descriptive names indicating operation + filters
- `!` suffix for exception-raising functions
- Consistent patterns across repositories

### Return Types
- `{:ok, entity}` - successful operations
- `{:error, :not_found}` - missing entities
- `{:error, changeset}` - validation failures
- `[entity]` - lists
- `Ecto.Query.t()` - query builders

## Content Guidelines

### Purpose Section
- One paragraph only
- Focus on data access role
- Mention key responsibilities

### Function Descriptions
- What each function does (not how)
- When/why to use it
- Note side effects and validations

### Error Handling
- List all error conditions
- Group by type (validation, not found, constraints)
- Use consistent formats

### Usage Patterns
- Architecture integration
- Common calling patterns
- Performance considerations

## Code Standards

### Type Definitions
```elixir
@type entity_attrs :: %{required_field: String.t()}
@type entity_status :: :created | :processing | :completed
```

### Query Composition Example
```elixir
Entity
|> Repository.by_project(project_id)
|> Repository.by_status(:active)
|> Repo.all()
```