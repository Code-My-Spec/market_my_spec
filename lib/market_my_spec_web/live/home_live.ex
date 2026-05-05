defmodule MarketMySpecWeb.HomeLive do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.McpAuth.ConnectionInfo
  alias MarketMySpec.Skills.Overview

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <%!-- Hero section --%>
      <section class="py-16 border-b border-base-300">
        <div class="max-w-3xl">
          <h1
            class="font-display text-4xl md:text-5xl leading-[1.05]"
            data-test="hero-headline"
            data-headline="Marketing for founders, in Claude Code"
          >
            Marketing for founders,<br />
            <span class="text-primary">in Claude Code.</span>
          </h1>
          <p class="mt-6 text-lg text-base-content/70 max-w-2xl">
            {@value_proposition}
          </p>

          <%!-- Install command block — mockup-code per design system --%>
          <div class="mockup-code mt-8" data-test="artifact-preview">
            <pre data-prefix="$"><code data-test="install-command">{@install_command}</code></pre>
            <pre data-prefix=">" class="text-success"><code>market-my-spec · connected</code></pre>
            <pre data-prefix=">" class="text-primary"><code>marketing-strategy skill · ready</code></pre>
          </div>

          <div class="mt-6 flex items-center gap-3">
            <button
              class="btn btn-primary"
              data-test="copy-button"
              phx-click="copy_install_command"
            >
              Copy install command
            </button>
            <.link navigate={~p"/mcp-setup"} class="btn btn-ghost">
              Setup guide
            </.link>
          </div>
        </div>
      </section>

      <%!-- BYO-Claude benefit section --%>
      <section class="py-10" data-test="byo-claude-benefit">
        <div class="flex items-start gap-4 py-3 border-b border-base-300">
          <span class="badge badge-primary mt-0.5 shrink-0">no markup</span>
          <div>
            <h2 class="font-display text-xl mb-1">Bring your own Claude</h2>
            <p class="text-base-content/70">
              Don't markup your tokens. Connect your existing Claude Code subscription.
              We pass through the API call directly. You own the conversation —
              no middleman, no surprises on your bill.
            </p>
          </div>
        </div>
      </section>

      <%!-- Feature cards --%>
      <section class="py-10">
        <h2 class="font-display text-2xl mb-8">{@target_audience}</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div :for={feature <- @features} class="card bg-base-200 border border-base-300">
            <div class="card-body">
              <h3 class="font-display text-sm uppercase tracking-wider text-base-content/60">
                {feature.title}
              </h3>
              <p class="text-sm text-base-content/80">{feature.description}</p>
            </div>
          </div>
        </div>
      </section>

      <%!-- Agency CTA — positioned below install, not equal weight --%>
      <section class="py-8 border-t border-base-300" data-test="agency-cta">
        <p class="font-mono text-xs uppercase tracking-wider text-base-content/50 mb-2">
          agency tier
        </p>
        <p class="text-base-content/80">
          Do you run an agency? We're building a service tier for agencies running this for clients.
          <.link
            href="mailto:johns10@gmail.com"
            class="link link-primary font-medium"
          >Talk to John</.link> about early access.
        </p>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:install_command, ConnectionInfo.install_command())
     |> assign(:value_proposition, Overview.value_proposition())
     |> assign(:target_audience, Overview.target_audience())
     |> assign(:features, Overview.features())}
  end

  @impl true
  def handle_event("copy_install_command", _params, socket) do
    {:noreply, socket}
  end
end
