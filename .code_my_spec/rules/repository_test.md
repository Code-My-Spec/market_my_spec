---
component_type: "repository"
session_type: "test"
---


# Repository Test Design Rules

## Test Structure
```elixir
defmodule App.Context.RepositoryTest do
  use App.DataCase, async: true
  
  import App.ContextFixtures
  
  alias App.Context.{Schema, Repository}
  alias App.Repo
  
  # Group tests by function with describe blocks
end
```

## Test Organization

### Describe Blocks
- One `describe` block per public function
- Use function name with arity: `describe "create_account/1"`
- Group related edge cases within the same describe block

### Test Coverage Per Function
- Happy path test (valid data succeeds)
- Validation error tests (invalid data fails appropriately)
- Constraint violation tests (uniqueness, foreign keys)
- Edge cases specific to business logic

## Fixture Usage

### Setup Data
- Use fixtures for test data creation: `account_fixture()`, `user_fixture()`
- Pass attributes to fixtures for specific scenarios: `account_fixture(%{slug: "test"})`
- Create composite fixtures for complex setups: `account_with_owner_fixture(user)`

### No Mocks
- Test against actual database operations
- Use real data and verify actual state changes
- Assert on database state after operations

## Assertion Patterns

### CRUD Operations
- **Create**: Assert return tuple, verify attributes, check database persistence
- **Get**: Assert returned data matches expected, test nil returns
- **Update**: Verify changes applied, assert unchanged fields remain
- **Delete**: Confirm removal from database, test cascade behavior

### Error Cases
- Assert `{:error, changeset}` return format
- Use `errors_on(changeset)` to verify specific field errors
- Test constraint violations with appropriate error messages

### Query Builders
- Test query composition with `Repo.all(query)`
- Verify filtering logic with known test data
- Assert preloads work with `Ecto.assoc_loaded?/1`

## Database State Verification

### Direct Database Checks
- Use `Repo.get_by/2` to verify records exist/don't exist
- Check associations are properly created/deleted
- Verify cascade behavior on deletions

### Transaction Testing
- Test complex operations that involve multiple repositories
- Verify rollback scenarios when part of operation fails
- Assert all-or-nothing behavior for multi-step operations

## Test Data Strategies

### Isolation
- Use `async: true` when tests don't interfere
- Each test creates its own data via fixtures
- No shared state between tests

### Edge Cases
- Test boundary conditions (empty strings, large values)
- Verify handling of non-existent IDs
- Test reserved values or special business rules

## Query Composition Testing

### Individual Builders
- Test each query builder function separately
- Verify they return proper `Ecto.Query.t()` structures
- Test with known data and verify filtering

### Combined Usage
- Show query builders can be composed together
- Test realistic query patterns from the application
- Verify performance considerations (preloads, N+1 prevention)