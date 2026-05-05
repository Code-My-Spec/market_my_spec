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
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
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
    <header class="border-b border-base-300 bg-base-200">
      <div class="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between gap-6">
        <a href="/" class="flex items-baseline gap-3">
          <span class="font-display text-lg tracking-tight">
            marketmyspec<span class="text-primary">.</span>
          </span>
        </a>
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
