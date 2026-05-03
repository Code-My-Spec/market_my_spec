---
component_type: "*"
session_type: "design"
---

- Structure applications as hierarchical supervision trees
- Put critical, stable processes at the top and volatile, expendable processes at the bottom
- Use OTP behaviors (GenServer, Supervisor, GenStateMachine) as design patterns for processes.
- Don't try to handle every edge case
- Fail predictably and quickly and recover automatically using supervision
- Design the application as independent processes, communicating via message passing
- Each process should have a single, clear responsibility with well-defined boundaries
- Model complex business processes as explicit state machines using GenStateMachine or similar patterns
- Design for distribution from day one, using distributed Erlang capabilities for seamless process communication across nodes
- Architect applications so components can be upgraded, replaced, or scaled without system shutdown using hot code swapping
- Design a functional core containing pure business logic and an imperative shell handling side effects
- The shell can call the core, but not vice versa

Use coordination contexts for cross-context operations instead of adopting layered architectures. Create explicit coordination modules when operations span multiple bounded contexts while maintaining context autonomy.

Design Phoenix Contexts as bounded context boundaries that decouple and isolate parts of your application, following Domain-Driven Design principles. Each context should encapsulate data access, validation, and business logic for a specific domain with clear boundaries.