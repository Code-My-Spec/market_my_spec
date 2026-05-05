defmodule MarketMySpecWeb.McpSetupLive do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.McpAuth.ConnectionInfo

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Connect Market My Spec to Claude Code
        <:subtitle>Three steps to get the marketing-strategy skill in your editor</:subtitle>
      </.header>

      <ol class="steps steps-vertical mt-8">
        <li class="step step-primary" data-test="install-step">
          <div class="text-left ml-4">
            <h3 class="font-display text-sm uppercase tracking-wider">Install the MCP plugin</h3>
            <p class="text-sm text-base-content/70 mt-1">Run this in your terminal:</p>
            <div class="mockup-code mt-2 text-sm">
              <pre data-prefix="$"><code data-test="install-command">{@install_command}</code></pre>
            </div>
          </div>
        </li>
        <li class="step step-primary" data-test="oauth-step">
          <div class="text-left ml-4">
            <h3 class="font-display text-sm uppercase tracking-wider">Sign in via OAuth</h3>
            <p class="text-sm text-base-content/70 mt-1" data-test="oauth-instructions">
              Claude Code will open a browser for you to authorize the connection.
              Server URL:
            </p>
            <div class="mockup-code mt-2 text-sm">
              <pre data-prefix=">"><code data-test="server-url">{@server_url}</code></pre>
            </div>
          </div>
        </li>
        <li class="step step-primary" data-test="interview-step">
          <div class="text-left ml-4">
            <h3 class="font-display text-sm uppercase tracking-wider">Start your first interview</h3>
            <p class="text-sm text-base-content/70 mt-1">
              In Claude Code, ask: "start a marketing strategy interview" — the agent
              will load the skill and walk you through it.
            </p>
          </div>
        </li>
      </ol>

      <section
        class="mt-10 card bg-base-200 border border-success/40"
        data-test="expected-result"
      >
        <div class="card-body">
          <h3 class="font-display text-sm uppercase tracking-wider">How you know it worked</h3>
          <p class="text-sm mt-1 text-base-content/80">
            In Claude Code, <code class="font-mono text-primary">market-my-spec</code>
            appears under your connected MCP servers and the marketing-strategy skill is installed and ready to use.
          </p>
        </div>
      </section>

      <section class="mt-12">
        <h2 class="font-display text-xl">Troubleshooting</h2>

        <details
          class="mt-4 card bg-base-200 border border-base-300"
          data-test="port-conflict-troubleshooting"
        >
          <summary class="card-body font-display text-sm uppercase tracking-wider cursor-pointer select-none">
            Port conflict during install
          </summary>
          <div class="px-6 pb-6">
            <p class="text-sm text-base-content/70">
              If the install fails with an "address already in use" error, another process is bound to the
              port Claude Code uses for the MCP handshake. Find the offending process with
              <code class="font-mono text-xs bg-base-300 px-1.5 py-0.5">lsof -nP -iTCP:&lt;port&gt;</code>,
              stop it, and retry the install. Restart Claude Code if the conflict persists.
            </p>
          </div>
        </details>

        <details
          class="mt-4 card bg-base-200 border border-base-300"
          data-test="oauth-troubleshooting"
        >
          <summary class="card-body font-display text-sm uppercase tracking-wider cursor-pointer select-none">
            OAuth authorization failed
          </summary>
          <div class="px-6 pb-6">
            <p class="text-sm text-base-content/70">
              If the browser shows an authorization error or the consent screen never appears, confirm
              you're signed in to Market My Spec in the same browser, then run the install again.
              Stale OAuth sessions occasionally need a fresh sign-in — log out and back in before retrying.
              If the redirect URI is rejected, your Claude Code version may be older than the MCP 2025-03-26 spec;
              update Claude Code and retry.
            </p>
          </div>
        </details>

        <details
          class="mt-4 card bg-base-200 border border-base-300"
          data-test="mcp-connection-troubleshooting"
        >
          <summary class="card-body font-display text-sm uppercase tracking-wider cursor-pointer select-none">
            MCP connection drops or never connects
          </summary>
          <div class="px-6 pb-6">
            <p class="text-sm text-base-content/70">
              If <code class="font-mono text-xs bg-base-300 px-1.5 py-0.5">market-my-spec</code>
              shows up but never reaches a connected state, restart Claude Code first. If the issue persists, run
              <code class="font-mono text-xs bg-base-300 px-1.5 py-0.5">claude mcp list</code>
              to confirm the server URL matches what's shown above, and re-run the install command if the URL drifted.
              Network proxies and corporate firewalls can also block the connection.
            </p>
          </div>
        </details>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    info = ConnectionInfo.setup_info()

    {:ok,
     socket
     |> assign(:install_command, info.install_command)
     |> assign(:server_url, info.server_url)}
  end
end
