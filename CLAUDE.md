<!-- code_my_spec:start -->
## CodeMySpec — Development Harness

This project is managed by **CodeMySpec**, a requirements-driven development harness.
Read `.code_my_spec/AGENTS.md` for the full workflow guide.

### How It Works

CodeMySpec tracks every artifact your project needs — specs, tests, implementations,
reviews, BDD scenarios — as a **requirement graph**. Each requirement has prerequisites,
so you always know what to work on next and in what order.

### Your Workflow

1. **`get_next_requirement`** — returns the highest-priority unsatisfied requirement
   whose prerequisites are all met.
2. **`start_task`** — begins work on that requirement. Returns a detailed prompt
   with context, rules, file paths, and instructions.
3. **Do the work** — write the spec, test, implementation, or review as instructed.
4. The harness **automatically evaluates** your output on stop, checking file existence,
   validity, compilation, and test results. If something is wrong, you get feedback.
5. **Repeat** — call `get_next_requirement` again.

### Key Rules

- **Always follow the task prompt.** It contains spec templates, design rules, file paths,
  and test patterns specific to the component you're working on.
- **Read before you write.** The task prompt tells you which specs, rules, and existing
  files to read. Do it.
- **One requirement at a time.** The graph handles ordering. Don't skip ahead.
- Specs live in `.code_my_spec/spec/`, rules in `.code_my_spec/rules/`, architecture in `.code_my_spec/architecture/`.
<!-- code_my_spec:end -->
