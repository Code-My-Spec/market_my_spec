# QA Brief — Story 742: Set the money-gate threshold at Frame time

## Tool

web

## Auth

Login via the password form at `http://localhost:4007/users/log-in`:

1. Navigate to `http://localhost:4007/users/log-in`
2. Scroll the password form into view: selector `#login_form_password`
3. Fill email: `#login_form_password_email` with `qa@marketmyspec.test`
4. Fill password: `#user_password` with `hello world!`
5. Click: `#login_form_password button[name='user[remember_me]']`
6. Wait for redirect away from `/users/log-in`

## Seeds

Run the primary seed script to create the QA user and account:

```
cd /Users/johndavenport/Documents/github/market_my_spec && mix run priv/repo/qa_seeds.exs
```

No story-specific seed script is required for story 742. The Frame compose
form creates Frames directly from the browser.

## What To Test

### Scenario 1: Frames index loads and shows "New Frame" button (AC: typed threshold axes)

- Visit `http://localhost:4007/problem-discovery/frames`
- Expect: page loads without error, "Problem Discovery Frames" heading visible
- Expect: "New Frame" button or link is visible
- Screenshot: frames index page

### Scenario 2: New Frame compose form exposes typed threshold fields (AC: total_spent_min and hire_rate_min as typed threshold axes)

- Visit `http://localhost:4007/problem-discovery/frames/new`
- Expect: form with `data-test="frame-form"` is visible
- Expect: `input[name='frame[total_spent_min]']` field is present with a numeric default
- Expect: `input[name='frame[hire_rate_min]']` field is present with a numeric default
- Expect: `input[name='frame[min_money_gated_candidates]']` field is present (kill_condition)
- Screenshot: new Frame form with all threshold fields visible

### Scenario 3: Founder's threshold values land on the Frame verbatim (AC: threshold values land verbatim, kill_condition is structured)

- Visit `http://localhost:4007/problem-discovery/frames/new`
- Fill description: "QA hypothesis — vendor onboarding pain"
- Fill saved_searches_text: "upwork: vendor onboarding\nupwork: supplier consolidation\nupwork: intake automation"
- Fill `frame[total_spent_min]`: 7500
- Fill `frame[hire_rate_min]`: 65
- Fill `frame[min_money_gated_candidates]`: 4
- Submit the form (click "Commit Frame" button)
- Expect: success flash "Frame created." and redirect to `/problem-discovery/frames/<id>`
- Screenshot: after successful commit, Frame detail page

### Scenario 4: Frame detail page shows threshold values alongside results (AC: Board shows producing Frame's threshold values)

- After committing the Frame in Scenario 3, on the Frame detail page:
- Expect: `total_spent_min: $7500` (or `7,500`) visible in the header area
- Expect: `hire_rate_min: 65%` visible in the header area
- Screenshot: Frame detail header showing threshold values

### Scenario 5: Form validation rejects Frame without kill_condition (AC: Frame commit rejected without kill_condition)

- Visit `http://localhost:4007/problem-discovery/frames/new`
- Fill description: "Test frame"
- Fill saved_searches_text: "upwork: test query"
- Fill `frame[total_spent_min]`: 5000
- Fill `frame[hire_rate_min]`: 50
- Clear `frame[min_money_gated_candidates]` to 0 or empty
- Submit
- Observe: either a validation error is shown, or if 0 is accepted by the form (parse_int returns 0), note the behavior
- Screenshot: form state after submission attempt

### Scenario 6: Score halts when Frame has no money_gate (AC: Score halts with no money-gate threshold)

- This criterion is tested at the pipeline level (bypassing changeset by inserting a Frame with nil money_gate). The spex exercises this directly via `Pipeline.score/1`. In the browser, all Frame creation goes through the changeset which requires money_gate, so there is no UI path to a Frame without one. Verify the form won't submit without threshold values by clearing both threshold fields and attempting submission.
- Visit `http://localhost:4007/problem-discovery/frames/new`
- Clear total_spent_min and hire_rate_min fields to empty
- Submit
- Observe: validation error or default 0 substitution behavior
- Screenshot: any error state

### Scenario 7: kill_condition structured data validation (AC: kill_condition is structured data, not prose)

- This criterion is validated at the changeset level. The UI only surfaces a numeric `min_money_gated_candidates` input, making it impossible to submit prose as a kill_condition from the browser. Verify the field is a number input (not a text textarea).
- On the new Frame form, confirm `input[name='frame[min_money_gated_candidates]']` has `type="number"`
- Screenshot: form input type inspection (annotated screenshot showing field)

## Result Path

`.code_my_spec/qa/742/result.md`
