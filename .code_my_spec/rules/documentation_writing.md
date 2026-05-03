---
component_type: "content"
session_type: "design"
---

# Documentation Writing

Write technical documentation that focuses on accurate reference information and practical usage guidance, not persuasion or marketing.

## Core Structure

Documentation pages should include:

1. **Overview** (1-2 paragraphs) - What this is and what it does technically
2. **How to Use It** (Prerequisites + typical workflow) - Setup and common usage pattern
3. **Available Tools/API Reference** (comprehensive listing) - Every endpoint, parameter, return value
4. **Security & Constraints** - Permission model, scoping, limitations
5. **Integration Points** - How this connects technically to other system components
6. **Tips for Effective Use** - Practical advice from experience, edge cases, gotchas

## Voice and Tone

- **Precise over persuasive** - State facts, not benefits
- **Comprehensive over concise** - Include all details, don't summarize away important info
- **Technical over simplified** - Use accurate terminology, assume developer audience
- **Instructive over descriptive** - Show how to accomplish tasks, not just what exists

## Documentation vs Marketing

**Documentation answers:**
- What parameters does this function accept?
- What does each status value mean?
- How do I link a story to a component?
- What happens when X fails?
- What are the exact field names and types?

**Marketing answers:**
- Why should I use this?
- What problem does this solve?
- What makes this different?
- How does this benefit my workflow?

If your sentence could appear in a landing page or sales pitch, it belongs in marketing, not docs.

## Structure Guidelines

### API/Tool Reference Format
For each tool or endpoint:

```markdown
### tool_name

**Purpose:** One-sentence description of what it does

**Parameters:**
- `param_name` (type, required/optional): Description
- `param_name` (type, required/optional): Description

**Returns:** Description of return value or structure

**Behavior:** (if complex)
- Specific behavior notes
- Edge cases
- Failure modes

**Example:** (code or JSON showing actual usage)
```

### Data Model Format
Show actual structure using code:

```markdown
## Entity Data Model

\`\`\`elixir
%Entity{
  field_name: type  # description
  field_name: :enum1 | :enum2  # description
  ...
}
\`\`\`

**Field Details:**
- `field_name`: Purpose, constraints, defaults
```

### Workflow Format
Use ordered lists with concrete actions:

```markdown
### Typical Workflow

1. **Action name** - What happens technically
2. **Action name** - What happens technically
...
```

## What to Include

- **Every parameter** with type, requirement status, and description
- **All return values** including error cases
- **Validation rules** and constraints
- **Status/enum values** with exact meanings
- **Scoping rules** (multi-tenancy, permissions)
- **Side effects** (broadcasts, cascading updates)
- **Integration points** (what other systems/tools this touches)
- **Actual examples** with real field names and values
- **Edge cases** and failure scenarios
- **Version/audit info** if relevant

## What to Exclude

- Marketing copy about benefits or competitive advantages
- Philosophical arguments for why this approach is better
- Motivational framing ("This makes your life easier!")
- Problem statements that pitch the solution
- Feature comparison charts
- Getting started sections that belong in tutorials
- Testimonials or use case stories

## Organization Principles

- **Reference-style ordering**: Group by category (CRUD operations, analysis tools, workflow tools)
- **Alphabetical within categories**: Predictable ordering for scanning
- **Link to related docs**: Cross-reference other technical documentation
- **Separate tutorials from reference**: Step-by-step guides are different from API docs
- **Progressive detail**: Overview → Categories → Individual items → Examples

Documentation should be the source of truth that developers reference when implementing, debugging, or integrating. It should be boring, accurate, and comprehensive.