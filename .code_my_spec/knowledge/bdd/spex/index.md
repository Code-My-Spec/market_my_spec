# BDD Spex — Market My Spec project plan

How BDD specs work in **this** project. The framework rules at
`.code_my_spec/framework/bdd/spex/` define the generic shape (sealed
boundary, in-memory env, given/when/then DSL, two-users-two-surfaces).
This document tailors them to MMS — what surfaces a spec is allowed
to drive here, what fixtures are sanctioned, and which anti-patterns
keep biting.

## Two users, MMS-flavored

| User | Surface | How specs drive it |
|---|---|---|
| Solo founder (web) | Phoenix LiveView under `MarketMySpecWeb` | `live/2`, `form/2`, `render_submit/1`, `render_click/1` via `Phoenix.LiveViewTest` |
| Connected agent (Claude Code) | MCP transport at `MarketMySpecWeb.McpController` | JSON-RPC POSTs to `/mcp` with bearer; `tools/call` for `invoke_skill`, `read_skill_file` |

There are no engineer/CLI users — MMS is purely a web + MCP server.

## Public surfaces a spec MAY drive

LiveViews (drive via `Phoenix.LiveViewTest`):

| Module | Route | Stories |
|---|---|---|
| `MarketMySpecWeb.HomeLive` | `/` | 633 |
| `MarketMySpecWeb.UserLive.Login` | `/users/log-in` | 609, 672, 673 |
| `MarketMySpecWeb.UserLive.Registration` | `/users/register` | 609 |
| `MarketMySpecWeb.UserLive.Confirmation` | `/users/log-in/:token` | 609 |
| `MarketMySpecWeb.UserLive.Settings` | `/users/settings` | (infrastructure) |
| `MarketMySpecWeb.McpSetupLive` | `/mcp-setup` | 611, 634 |
| `MarketMySpecWeb.McpAuthorizationLive` | `/oauth/authorize` (consent UI render) | 612 |

Controllers (drive via `Phoenix.ConnTest` + `post/3`, `get/2`, `delete/2`):

| Module | Route(s) | Stories |
|---|---|---|
| `MarketMySpecWeb.UserSessionController` | `POST /users/log-in`, `DELETE /users/log-out`, `POST /users/update-password` | 609 |
| `MarketMySpecWeb.IntegrationsController` | `GET /integrations/oauth/:provider`, `GET /integrations/oauth/callback/:provider` | 672, 673 |
| `MarketMySpecWeb.McpController` | `POST /mcp` (JSON-RPC over SSE), `POST /oauth/token`, `POST /oauth/revoke`, `POST /oauth/register`, `GET /.well-known/oauth-authorization-server`, `GET /.well-known/oauth-protected-resource` | 612, 674, 675, 676 |

That's the full list. Anything else is internal and the project-local
Credo check at `.code_my_spec/credo_checks/local/market_my_spec_spex_denies.ex`
+ the `MarketMySpecSpex` Boundary declaration both block it.

## MCP tools in specs — call `Tool.execute/2` directly with an `Anubis.Server.Frame`

Anubis tool components are pure modules with an `execute(args, frame)`
callback. The transport (StreamableHTTP plug, SSE correlation, bearer
validation) is what production runs through, but specs don't need any
of that — they call the tool module directly with a synthesized Frame
that carries the auth scope. This is the pattern CodeMySpec uses for
all of its MCP-tool specs.

The pattern:

```elixir
defmodule MarketMySpecSpex.Story674.Criterion5731Spex do
  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.Marketing.Tools.InvokeSkill

  setup :register_log_in_setup_account

  spex "Start Marketing Strategy Interview" do
    scenario "User runs /marketing-strategy and the agent loads the playbook" do
      given_ "an authenticated user", context do
        # context.scope is built by register_log_in_setup_account
        {:ok, context}
      end

      when_ "the agent calls invoke_skill", context do
        frame = %Frame{assigns: %{current_scope: context.scope}}

        {:reply, response, _frame} =
          InvokeSkill.execute(%{skill_name: "marketing-strategy"}, frame)

        {:ok, Map.put(context, :prompt, response_text(response))}
      end

      then_ "the orientation prompt body is returned", context do
        assert context.prompt =~ "name: marketing-strategy"
        assert context.prompt =~ "steps/01_current_state.md"
        :ok
      end
    end
  end

  defp response_text(%{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{text: t} -> t
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(%{text: text}), do: text
  defp response_text(other), do: inspect(other)
end
```

What this does and doesn't exercise:

- **DOES exercise:** the tool module's argument validation, its call
  into the domain (`MarketMySpec.Skills.MarketingStrategy` for skill
  content), filesystem reads against `priv/skills/`, response shape.
- **DOES NOT exercise:** the StreamableHTTP plug, SSE session
  correlation, bearer-token validation, the OAuth flow that issues
  the bearer. Those are tested separately as plug specs (see Controllers
  table) — typically one spec asserting bearer rejection on 401, and
  one spec asserting a valid bearer reaches the tool. If those two
  pass, every other MCP spec drives the tool module directly.

### Tool module namespace

Tool modules live under `MarketMySpec.McpServers.<server>.Tools.<tool>`
(mirroring the CodeMySpec convention). For the marketing-strategy
skill, expect:

- `MarketMySpec.McpServers.Marketing.Tools.InvokeSkill`
- `MarketMySpec.McpServers.Marketing.Tools.ReadSkillFile`

Plus the Anubis server module that registers them as components:

- `MarketMySpec.McpServers.Marketing.Server`

`MarketMySpec.McpServers` is its own top-level Boundary (deps:
`[MarketMySpec, MarketMySpec.Repo]` plus whatever contexts the tools
need to read from), exporting all Tools modules. That lets the Spex
boundary depend on `MarketMySpec.McpServers` without depending on
`MarketMySpec` directly — specs reach the agent surface, not the
internal contexts.

### When McpServers ships, update

1. `MarketMySpecSpex` boundary deps: add `MarketMySpec.McpServers`.
2. `lib/market_my_spec/mcp_servers.ex`: declare the McpServers
   boundary with the right deps and `exports: :all`.
3. The OAuth-flow specs that test `/oauth/token`, `/oauth/authorize`,
   `/.well-known/...` use `Phoenix.ConnTest` — those don't need
   Anubis at all, just standard controller specs.

## Fixture inventory — what `given_` may set up

`MarketMySpecSpex.Fixtures` is the only legal escape hatch. Current
exports (keep this list synced with the actual module):

| Function | What it does | When to use it |
|---|---|---|
| `setup_sandbox/1` | DB sandbox setup, called from `MarketMySpecSpex.Case` | Always (transitively) |
| `user_fixture/1` | Confirmed user with magic-link consumed | When the spec needs a logged-in identity to start; the act-of-confirming is itself exercised by specs that drive UserLive.Confirmation |
| `unconfirmed_user_fixture/1` | Unconfirmed user, only registered | When a spec exercises confirmation flow itself |
| `user_scope_fixture/0,1` | `%MarketMySpec.Users.Scope{}` for the user | When a controller/LiveView spec needs `current_scope` pre-set |
| `generate_user_magic_link_token/1` | Single-use magic-link token | When a spec drives `UserLive.Confirmation` without a real outbox round-trip |

If a scenario needs state outside this list:

1. Can the state be produced by driving the LiveView? (Preferred — sign-up via magic link, OAuth via the IntegrationsController callback, OAuth-server consent via `/oauth/authorize`.)
2. Can it be produced by completing the canonical agent flow? (The `Integrations.Integration` row IS produced by the OAuth callback flow; the access-token row IS produced by `/oauth/token`. Drive those, don't seed the rows.)
3. Is this state that genuinely originates server-side? Then add a defdelegate to `MarketMySpecSpex.Fixtures`. Leave a one-line comment above it justifying inclusion.

## Legal `then_` observation surfaces

For LiveView specs:

- Rendered HTML — `render(view)`, `has_element?(view, "[data-test='X']")`.
- Form state on the live view in context — `element(view, "input[name='user[email]']") |> render() =~ "qa@..."`.
- Flash messages — `assert render(view) =~ "Successfully connected"`.
- Redirect targets — `assert {:error, {:redirect, %{to: "/mcp-setup"}}} = live(conn, "/oauth/authorize?...")`.

For controller specs:

- HTTP status — `response(conn, 200)`.
- JSON body — `json_response(conn, 200)`.
- Headers — `Plug.Conn.get_resp_header(conn, "www-authenticate")`.
- Redirect target — `redirected_to(conn, 302) == "/mcp-setup"`.

For MCP / OAuth flows:

- The bearer token returned from `/oauth/token` (assert shape, then use it as input to a follow-up MCP request).
- The body returned by `tools/call` over the SSE channel (via the test client helper).
- The metadata returned by `/.well-known/oauth-authorization-server` and `/.well-known/oauth-protected-resource` — JSON shape matching RFC 8414 / RFC 9728.

For email side effects:

- Swoosh local mailbox — `assert_email_sent fn email -> ... end` (when a spec drives a magic-link or OAuth flow that sends mail).

What `then_` may **not** do:

- Read `MarketMySpec.Repo` directly.
- Call `MarketMySpec.Users.get_user_by_email/1` or any context function.
- Pattern-match against a fixture's underlying schema row to "prove" the outcome.
- Touch the real filesystem (everything user-visible that involves files happens *on the user's machine*, not on the server — see story 676 anti-patterns below).

## Project-specific anti-patterns

### Don't seed `MarketMySpec.Skills` rows or synthesize skill content

The marketing-strategy skill is **file-backed** under
`priv/skills/marketing-strategy/`. The MCP tools `invoke_skill` and
`read_skill_file` read those files. Specs that need to assert on
skill content read the same files via `File.read!` *inside the
implementation* — not via a Skills context call. Spec assertions
about skill content compare the response body of `invoke_skill` /
`read_skill_file` to the on-disk file content, ideally via a fixture
that captures the canonical bytes.

### Don't seed `MarketMySpec.McpAuth.AccessToken` rows

The way an MCP client gets a bearer is by completing the OAuth
auth-code + PKCE flow. Specs drive `POST /oauth/register`,
`GET /oauth/authorize` with a signed-in session, `POST /oauth/token`,
and capture the bearer from the `/oauth/token` response body. The
issued token is then used as input to subsequent MCP calls. If a
scenario short-circuits and seeds an access-token row directly, it's
testing the MCP plug's bearer parsing in isolation — fine for a unit
test, not a spec.

### Don't seed `MarketMySpec.Integrations.Integration` rows

The Google/GitHub integration row is produced by the OAuth callback
controller. Specs drive `GET /integrations/oauth/:provider` to start
the flow, then simulate the provider's callback by posting to
`GET /integrations/oauth/callback/:provider?code=...&state=...` with
a recorded ExVCR cassette for the provider's token endpoint. Seeding
the integration row directly bypasses the cassette and the
controller's normalization step.

### Don't read `marketing/` files from the host filesystem

The strategy artifacts that step files instruct the agent to write
land **on the user's machine** via the agent's own Write tool.
Server-side specs cannot observe these files because they don't
exist on the server. Story 676 specs are static-content audits over
`priv/skills/marketing-strategy/` (asserting the step files contain
the correct write instructions and destination paths) plus tool
surface audits over the MCP `tools/list` response. There is no
"spec writes a file, asserts the file exists" pattern in MMS.

### Don't ride `MarketMySpec.Repo.update_all/2` to fast-forward token state

Magic-link expiry, token consumption, OAuth grant expiry — these
all change row state. Don't `Repo.update_all` to age a token; use
the existing `MarketMySpec.UsersFixtures.offset_user_token/3` (which
the bridge re-exports if specs need it; expose via defdelegate when
the first scenario asks for it). Same pattern for OAuth grant
expiry — add a narrow Fixtures function instead of reaching into
Repo from the spec.

## File layout reminder

```
test/spex/<story_id>/<criterion_id>_spex.exs
```

Module: `MarketMySpecSpex.Story<id>.Criterion<id>Spex`. One file per
acceptance criterion (one per Three-Amigos scenario). Pull the title
and body straight from the criterion record.

Run with:

```
mix spex                         # whole suite
mix spex test/spex/674           # one story
mix spex test/spex/674/5731_spex.exs
```
