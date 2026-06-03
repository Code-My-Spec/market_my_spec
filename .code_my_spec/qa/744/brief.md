# QA Brief: Story 744 — Streaming LLM Chat UI

## Tool

web

## Auth

1. Navigate to http://localhost:4008/users/register
2. Register with email `qa+744@example.com` and a password (12+ chars)
3. Open http://localhost:4008/dev/mailbox, find the confirmation email, click the magic-link URL to confirm and sign in
4. If routed to account creation, create an account at http://localhost:4008/accounts/new
5. Navigate to http://localhost:4008/chat to reach the feature under test

Note: The dev port is 4008 (not the 4007 in plan.md — the server was started with PORT=4008).

## Seeds

No seed script required for this story. The chat context auto-creates a conversation on first mount for a logged-in user with an active account.

## What To Test

- **Send + echo (R1):** Navigate to /chat. Type a short message in the input (e.g., "Hello, draft a launch post for the granite shop") and submit. Assert a `[data-test='user-message']` bubble with that text appears immediately. Assert the input (name="message[content]") is not disabled and still usable.

- **Empty input rejection (R1 failure path):** Submit the form with blank text (no content or whitespace only). Assert no `[data-test='user-message']` appears. The form should still be present and empty.

- **Streaming + in-progress indicator (R2):** Send a message that prompts a real Anthropic API response (e.g., "Count from 1 to 20 slowly"). While the reply is streaming, assert `[data-test='streaming-indicator']` is visible and `[data-test='assistant-message']` contains partial text.

- **Persistence / reload after completion (R4/R6):** Wait for the streaming reply to finish (streaming-indicator disappears). Take note of the assistant content. Reload /chat. Assert the conversation is still there — both the user message and assistant reply appear in the thread without a streaming indicator. Assert `[data-test='token-badge']` shows a non-zero token count and `[data-test='cost-badge']` shows a cost value.

- **Model selector (R5):** In the header, locate `[data-test='model-form']`. Change the provider select (name="conversation[provider]") or model select (name="conversation[model]") to a different value and submit/change. Assert the selection is accepted (no error, page stays on /chat).

- **Recoverable error affordance (R8):** If during testing an API error occurs (`[data-test='message-error']` appears), assert `[data-test='retry-button']` is also present. Click it and assert the streaming recovers or shows a new attempt. This scenario is opportunistic — only verify if an error naturally occurs.

## Result Path

`.code_my_spec/qa/744/`
