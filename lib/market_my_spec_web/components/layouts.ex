defmodule MarketMySpecWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MarketMySpecWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the authenticated app layout — drawer + sidebar nav, full-bleed
  main column. Used by signed-in routes like `/files`, `/accounts`,
  `/integrations`, `/users/settings`, `/mcp-setup`.

  ## Examples

      <Layouts.app flash={@flash} current_scope={@current_scope}>
        <h1>Content</h1>
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open min-h-screen">
      <input id="app-drawer-toggle" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content flex flex-col bg-base-100">
        <header class="navbar bg-base-200 border-b border-base-300 gap-2">
          <div class="flex-none lg:hidden">
            <label
              for="app-drawer-toggle"
              class="btn btn-square btn-ghost"
              aria-label="Open navigation"
            >
              <.icon name="hero-bars-3" class="size-5" />
            </label>
          </div>
          <div class="flex-1 px-2 lg:px-6">
            <span class="font-display text-base tracking-tight">
              marketmyspec<span class="text-primary">.</span>
            </span>
          </div>
          <div class="flex-none px-2">
            <.theme_toggle />
          </div>
        </header>

        <main class="flex-1 px-4 py-6 sm:px-6 lg:px-8">
          {render_slot(@inner_block)}
        </main>
      </div>

      <div class="drawer-side z-20">
        <label
          for="app-drawer-toggle"
          aria-label="close navigation"
          class="drawer-overlay"
        >
        </label>
        <aside class="w-64 min-h-full bg-base-200 border-r border-base-300 flex flex-col">
          <div class="p-6 border-b border-base-300">
            <a href="/" class="flex items-baseline gap-3">
              <span class="font-display text-lg tracking-tight">
                marketmyspec<span class="text-primary">.</span>
              </span>
            </a>
          </div>
          <ul class="menu p-4 text-base-content flex-1">
            <li>
              <.link navigate={~p"/files"}>
                <.icon name="hero-folder" class="size-4" /> Files
              </.link>
            </li>
            <li>
              <.link navigate={~p"/accounts"}>
                <.icon name="hero-building-office-2" class="size-4" /> Accounts
              </.link>
            </li>
            <li :if={@current_scope && @current_scope.active_account_id}>
              <.link navigate={~p"/accounts/#{@current_scope.active_account_id}/venues"}>
                <.icon name="hero-map-pin" class="size-4" /> Venues
              </.link>
            </li>
            <li :if={@current_scope && @current_scope.active_account_id}>
              <.link navigate={~p"/accounts/#{@current_scope.active_account_id}/searches"}>
                <.icon name="hero-magnifying-glass" class="size-4" /> Saved searches
              </.link>
            </li>
            <li :if={@current_scope && @current_scope.active_account_id}>
              <.link navigate={~p"/accounts/#{@current_scope.active_account_id}/threads"}>
                <.icon name="hero-chat-bubble-left-right" class="size-4" /> Threads
              </.link>
            </li>
            <li :if={@current_scope && @current_scope.active_account_id}>
              <.link navigate={~p"/accounts/#{@current_scope.active_account_id}/touchpoints"}>
                <.icon name="hero-paper-airplane" class="size-4" /> Touchpoints
              </.link>
            </li>
            <li>
              <.link navigate={~p"/integrations"}>
                <.icon name="hero-puzzle-piece" class="size-4" /> Integrations
              </.link>
            </li>
            <li>
              <.link navigate={~p"/mcp-setup"}>
                <.icon name="hero-command-line" class="size-4" /> MCP setup
              </.link>
            </li>
            <li class="mt-2 border-t border-base-300 pt-2">
              <.link navigate={~p"/users/settings"}>
                <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
              </.link>
            </li>
          </ul>

          <div :if={@current_scope} class="p-4 border-t border-base-300 flex flex-col gap-2">
            <div class="text-xs opacity-60 px-1 truncate" title={@current_scope.user.email}>
              {@current_scope.user.email}
            </div>
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="btn btn-ghost btn-sm justify-start"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Log out
            </.link>
          </div>
        </aside>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the marketing / public layout — narrow center column with a top
  brand header. Used by signed-out and content-style routes (`/`,
  `/users/log-in`, `/users/register`, etc.).

  ## Examples

      <Layouts.marketing flash={@flash}>
        <h1>Content</h1>
      </Layouts.marketing>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_agency, :map,
    default: nil,
    doc: "the agency resolved from the request host, or nil on the apex"

  slot :inner_block, required: true

  def marketing(assigns) do
    ~H"""
    <header
      class="border-b border-base-300 bg-base-200"
      style={agency_style(@current_agency)}
      data-agency-primary={agency_color(@current_agency, :primary_color)}
      data-agency-secondary={agency_color(@current_agency, :secondary_color)}
    >
      <div class="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between gap-6">
        <%= if @current_agency do %>
          <a href="/" data-test="agency-navbar-logo" class="flex items-center gap-3">
            <%= if @current_agency.logo_url && @current_agency.logo_url != "" do %>
              <img
                src={@current_agency.logo_url}
                alt={@current_agency.name}
                class="h-8 w-auto"
              />
            <% end %>
            <span class="font-display text-lg tracking-tight">
              {@current_agency.name}
            </span>
          </a>
        <% else %>
          <a href="/" class="flex items-baseline gap-3">
            <span class="font-display text-lg tracking-tight">
              marketmyspec<span class="text-primary">.</span>
            </span>
          </a>
        <% end %>
        <div class="flex items-center gap-3">
          <.theme_toggle />
        </div>
      </div>
    </header>

    <main class="max-w-6xl mx-auto px-4 py-10 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-3xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  defp agency_style(nil), do: nil

  defp agency_style(agency) do
    [
      maybe_var("--color-primary", agency.primary_color),
      maybe_var("--color-secondary", agency.secondary_color)
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      vars -> Enum.join(vars, "; ")
    end
  end

  defp maybe_var(_name, nil), do: nil
  defp maybe_var(_name, ""), do: nil
  defp maybe_var(name, value), do: "#{name}: #{value}"

  defp agency_color(nil, _field), do: nil

  defp agency_color(agency, field) do
    case Map.get(agency, field) do
      nil -> nil
      "" -> nil
      value -> value
    end
  end

  @doc """
  Provides dark vs light theme toggle based on the brand themes defined in app.css.

  Switches between marketmyspec-dark and marketmyspec-light.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="flex items-center border border-base-300 rounded-box overflow-hidden">
      <button
        class="flex p-2 cursor-pointer hover:bg-base-300 [[data-theme=marketmyspec-dark]_&]:bg-base-300"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="marketmyspec-dark"
        aria-label="Dark theme"
        title="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button
        class="flex p-2 cursor-pointer hover:bg-base-300 [[data-theme=marketmyspec-light]_&]:bg-base-300"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="marketmyspec-light"
        aria-label="Light theme"
        title="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
