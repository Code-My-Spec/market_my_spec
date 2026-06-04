# QA Brief: Story 745 — Chat Assistant Uses MarketMySpec MCP Tools

## Tool

web

## Auth

1. Navigate to http://localhost:4008/users/register and register with `qa+745@example.com`.
2. Open http://localhost:4008/dev/mailbox, find the confirmation/magic-link email, and click the link to sign in.
3. If prompted for account creation, go to http://localhost:4008/app/accounts/new and create one.
4. Navigate to http://localhost:4008/app/chat to reach the chat surface.

## Seeds

No dedicated seed script is required. The primary seed script can optionally be run to ensure a base user exists:

```
mix run priv/repo/qa_seeds.exs
```

For the account-scoping scenario (criterion 6602), two separate accounts with problem frames are needed. Create a problem frame at http://localhost:4008/app/problem-discovery/frames/new after signing in with the QA user, so `list_frames` returns real data.

## What To Test

### Scenario 1: Type picker — chat type chosen at creation (criteria 6604)
- Navigate to http://localhost:4008/app/chat
- Locate `[data-test='new-chat-form']` in the header; it contains a `<select name="conversation[type]">` with options `problem_discovery` and `marketing_strategy`
- Select "Problem Discovery" and click "New"
- Assert: `[data-test='chat'][data-chat-type='problem_discovery']` is present
- Select "Marketing Strategy" and click "New"
- Assert: `[data-test='chat'][data-chat-type='marketing_strategy']` is present
- Capture screenshot as evidence

### Scenario 2: Tool call triggered and shown live (criterion 6596)
- Start a Problem Discovery chat via the type picker
- In `[data-test='chat-form']`, send: "Use your tools to list my problem-discovery frames, then summarize them."
- Wait for the reply to complete (streaming indicator disappears)
- Assert: `[data-test='tool-call']` element appears in the message thread
- Assert: the tool-call element shows a tool name (e.g., `list_frames`)
- Capture screenshot of the tool-call step

### Scenario 3: Reply continues after tool result (criterion 6598)
- In the same Problem Discovery chat, observe the assistant's final reply
- Assert: `[data-test='assistant-message']` contains a substantive text response after the tool-call step
- Assert: `[data-test='streaming-indicator']` is not present (reply completed)
- Assert: `[data-test='message-error']` is not present
- Capture screenshot

### Scenario 4: Tool activity survives reload (criterion 6600)
- After the tool-using exchange completes, reload the page (navigate to http://localhost:4008/app/chat again)
- Assert: `[data-test='tool-call']` is still present in the thread
- Assert: the assistant message text is still present
- Assert: `[data-test='streaming-indicator']` is not present
- Capture screenshot post-reload

### Scenario 5: Plain message streams without tool call (criterion 6603)
- Start a new chat (type: Problem Discovery or Marketing Strategy)
- Send: "hello"
- Wait for the reply to complete
- Assert: `[data-test='assistant-message']` appears with a plain text reply
- Assert: `[data-test='tool-call']` does NOT appear
- Capture screenshot

### Scenario 6: Token and cost badges present (criterion carryover from story 744)
- After any exchange, check `[data-test='token-badge']` shows a token count
- Check `[data-test='cost-badge']` shows a cost value if available

### Scenario 7: Real tool runs against the user's account (criterion 6597)
- Verify the tool-call result in Scenario 2 reflects the actual account's data (e.g., lists the problem frame created in Seeds, or returns an empty result if none created — either is acceptable as "the tool ran")
- The tool result should not reference data from a different account

## Result Path

`.code_my_spec/qa/745/`
