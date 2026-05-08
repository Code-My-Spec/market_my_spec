defmodule MarketMySpecWeb.FilesLive.Browser do
  @moduledoc """
  Side-by-side files explorer.

  Left pane: hierarchical tree of every artifact in the user's currently
  active account, mirroring the storage path structure.
  Right pane: the selected markdown artifact rendered as styled HTML.

  Both panes coexist on a single LiveView. Clicking a file in the tree
  navigates to `/files/<path>`; the same LiveView handles `/files` (no
  selection) and `/files/*key` (selected).

  Non-markdown files are out of scope: selecting one raises and the
  supervisor restarts the LV.
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Files

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Artifacts
        <:subtitle>Files your agent has written into this account's workspace.</:subtitle>
      </.header>

      <div class="mt-8 grid grid-cols-1 lg:grid-cols-[18rem_1fr] gap-6">
        <aside :if={@tree == []} data-test="empty-state" class="card bg-base-100 border border-base-300 self-start">
          <div class="card-body items-center text-center">
            <h2 class="card-title">No artifacts yet</h2>
            <p class="text-base-content/70">
              Run a skill from your MCP-connected agent (e.g. <code>/marketing-strategy</code>)
              to populate this workspace. Artifacts the agent persists via the
              <code>write_file</code> tool will appear here.
            </p>
          </div>
        </aside>

        <aside
          :if={@tree != []}
          data-test="file-tree"
          class="card bg-base-100 border border-base-300 self-start"
        >
          <div class="card-body p-2">
            <ul class="menu w-full">
              <.tree_nodes nodes={@tree} selected_key={@selected_key} />
            </ul>
          </div>
        </aside>

        <section data-test="file-pane" class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <%= cond do %>
              <% @selected_key == nil -> %>
                <p data-test="file-pane-empty" class="text-base-content/60">
                  Select a file from the tree to read it here.
                </p>
              <% @error -> %>
                <header class="flex items-center justify-between gap-4">
                  <h2 class="font-mono text-sm break-all">{@selected_key}</h2>
                </header>
                <p data-test="artifact-error" class="text-error mt-2">{@error}</p>
              <% true -> %>
                <header class="flex items-center justify-between gap-4">
                  <h2 class="font-mono text-sm break-all">{@selected_key}</h2>
                </header>
                <article data-test="file-content" class="markdown mt-4">
                  {Phoenix.HTML.raw(@rendered_html)}
                </article>
            <% end %>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :nodes, :list, required: true
  attr :selected_key, :string, default: nil

  defp tree_nodes(assigns) do
    ~H"""
    <li :for={node <- @nodes}>
      <%= case node do %>
        <% {:folder, name, path, children} -> %>
          <details open>
            <summary data-test={"tree-folder-#{path}"}>{name}</summary>
            <ul>
              <.tree_nodes nodes={children} selected_key={@selected_key} />
            </ul>
          </details>
        <% {:file, name, path, _entry} -> %>
          <.link
            patch={~p"/files/#{String.split(path, "/")}"}
            data-test={"tree-file-#{path}"}
            class={if path == @selected_key, do: "menu-active"}
          >
            {name}
          </.link>
      <% end %>
    </li>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:tree, load_tree(scope))
     |> assign(:selected_key, nil)
     |> assign(:rendered_html, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_params(%{"key" => key_segments}, _uri, socket) do
    key = Enum.join(List.wrap(key_segments), "/")
    {:noreply, load_selection(socket, key)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:selected_key, nil)
     |> assign(:rendered_html, nil)
     |> assign(:error, nil)}
  end

  defp load_selection(socket, key) do
    if markdown?(key) do
      case Files.get(socket.assigns.current_scope, key) do
        {:ok, body} ->
          socket
          |> assign(:selected_key, key)
          |> assign(:rendered_html, render_markdown(body))
          |> assign(:error, nil)

        {:error, _reason} ->
          socket
          |> assign(:selected_key, key)
          |> assign(:rendered_html, nil)
          |> assign(:error, "File not available.")
      end
    else
      raise "Non-markdown artifacts are out of scope: #{inspect(key)}"
    end
  end

  defp markdown?(key) do
    String.downcase(Path.extname(key)) in [".md", ".markdown"]
  end

  defp render_markdown(body) do
    MDEx.to_html!(body,
      extension: [
        strikethrough: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true
      ],
      render: [unsafe: false]
    )
  end

  defp load_tree(scope) do
    case Files.list(scope, "") do
      {:ok, entries} -> build_tree(entries)
      {:error, _reason} -> []
    end
  end

  defp build_tree(entries) do
    entries
    |> Enum.map(&{String.split(&1.key, "/"), &1})
    |> Enum.reduce(%{}, fn {segments, entry}, acc -> insert(acc, segments, entry) end)
    |> to_nodes("")
  end

  defp insert(tree, [leaf], entry), do: Map.put(tree, leaf, {:leaf, entry})

  defp insert(tree, [head | rest], entry) do
    sub = Map.get(tree, head, %{})
    sub = if match?({:leaf, _}, sub), do: %{}, else: sub
    Map.put(tree, head, insert(sub, rest, entry))
  end

  defp to_nodes(map, prefix) do
    map
    |> Enum.sort_by(fn {name, val} -> {leaf?(val), name} end)
    |> Enum.map(fn {name, val} ->
      path = if prefix == "", do: name, else: prefix <> "/" <> name

      case val do
        {:leaf, entry} -> {:file, name, path, entry}
        sub when is_map(sub) -> {:folder, name, path, to_nodes(sub, path)}
      end
    end)
  end

  defp leaf?({:leaf, _}), do: true
  defp leaf?(_), do: false
end
