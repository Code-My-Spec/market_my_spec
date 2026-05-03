defmodule MarketMySpec.Check.Warning.SpexDenies do
  use Credo.Check,
    id: "MARKET0001",
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Specs must reach in-app state through `MarketMySpecSpex.Fixtures` or by
      driving the public LiveView / controller / MCP-tool surface — never by
      calling internal contexts directly.

      Whole-module denies (the context modules themselves; their schema
      submodules — e.g. `MarketMySpec.Users.User` — are allowed because
      schemas are the legal type surface for assertions, not the legal way
      to mutate state):

      - `MarketMySpec.Repo` — direct DB bypasses every public surface.
      - `MarketMySpec.Mailer` — outgoing mail belongs to the controller /
        LiveView path; spec asserts on Swoosh local-mailbox observation,
        not by calling the mailer module.
      - `MarketMySpec.Vault` — Cloak vault is internal infra; never an
        acceptable spec surface.
      - `MarketMySpec.Users` — Users context. Specs drive UserLive.Login,
        UserLive.Registration, UserLive.Confirmation, or the OAuth callback
        controllers. Use `MarketMySpecSpex.Fixtures.user_fixture/1` only
        for state that originates server-side.
      - `MarketMySpec.Integrations` — OAuth-integration context. Specs
        drive `IntegrationsController` (Google/GitHub callback flow), not
        the context module.
      - `MarketMySpec.McpAuth` — OAuth-server context for MCP clients.
        Specs drive `/oauth/authorize`, `/oauth/token`, `/oauth/revoke`,
        `/oauth/register`, and the well-known metadata endpoints — not the
        context module.
      - `MarketMySpec.Skills` — skill content context. Specs drive
        `McpController` JSON-RPC tool calls (`invoke_skill`,
        `read_skill_file`), never the Skills context directly.

      If a scenario seems to need one of these, re-read
      `.code_my_spec/knowledge/bdd/spex/index.md` and prefer driving the
      user-facing surface.
      """
    ]

  @denied_whole_modules [
    MarketMySpec.Repo,
    MarketMySpec.Mailer,
    MarketMySpec.Vault,
    MarketMySpec.Users,
    MarketMySpec.Integrations,
    MarketMySpec.McpAuth,
    MarketMySpec.Skills
  ]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    if String.ends_with?(filename, "_spex.exs") do
      ctx = %{issue_meta: Context.build(source_file, params, __MODULE__), issues: []}
      Credo.Code.prewalk(source_file, &traverse/2, ctx).issues
    else
      []
    end
  end

  defp traverse(
         {{:., _, [{:__aliases__, meta, module_parts}, fun]}, _, _args} = ast,
         ctx
       ) do
    module = Module.concat(module_parts)

    if module in @denied_whole_modules do
      {ast, add_issue(ctx, meta, "#{inspect(module)}.#{fun}")}
    else
      {ast, ctx}
    end
  end

  defp traverse(ast, ctx), do: {ast, ctx}

  defp add_issue(ctx, meta, trigger) do
    issue =
      format_issue(
        ctx.issue_meta,
        message:
          "Call to `#{trigger}` is denied in _spex.exs files. Specs must reach state " <>
            "through `MarketMySpecSpex.Fixtures` or by driving the public LiveView / " <>
            "controller / MCP-tool surface. See `.code_my_spec/knowledge/bdd/spex/index.md`.",
        trigger: trigger,
        line_no: meta[:line],
        column: meta[:column]
      )

    %{ctx | issues: [issue | ctx.issues]}
  end
end
