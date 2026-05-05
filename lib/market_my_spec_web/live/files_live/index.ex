defmodule MarketMySpecWeb.FilesLive.Index do
  @moduledoc """
  Browses artifacts the user's MCP-connected agent has written into the
  current account's workspace, grouped by skill (top-level directory) and
  step (filename ordering).

  Reads through `MarketMySpec.Files.list/2`, which is already account-scoped
  by `current_scope.active_account_id`.
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

      <div :if={@groups == []} class="mt-8">
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body items-center text-center">
            <h2 class="card-title">No artifacts yet</h2>
            <p class="text-base-content/70">
              Run a skill from your MCP-connected agent (e.g. <code>/marketing-strategy</code>)
              to populate this workspace. Artifacts the agent persists via the
              <code>write_file</code> tool will appear here.
            </p>
          </div>
        </div>
      </div>

      <div :if={@groups != []} class="mt-8 space-y-8">
        <section :for={{skill, entries} <- @groups} class="space-y-4">
          <h3 class="text-lg font-semibold">{format_skill(skill)}</h3>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div :for={entry <- entries} class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-base">{entry.label}</h2>
                <p class="text-xs text-base-content/60 font-mono">{entry.key}</p>
                <div class="text-xs text-base-content/70 space-x-3">
                  <span>{format_size(entry.size)}</span>
                  <span :if={entry.last_modified}>{format_timestamp(entry.last_modified)}</span>
                </div>
                <div class="card-actions justify-end mt-2">
                  <.link navigate={~p"/files/#{entry.key}"} class="btn btn-sm btn-primary">
                    Open
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    {:ok, assign(socket, :groups, load_groups(scope))}
  end

  defp load_groups(scope) do
    case Files.list(scope, "") do
      {:ok, entries} -> entries |> Enum.map(&decorate/1) |> group_and_sort()
      {:error, _reason} -> []
    end
  end

  defp decorate(%{key: key} = entry) do
    {skill, label} = split_key(key)

    entry
    |> Map.put(:skill, skill)
    |> Map.put(:label, label)
  end

  defp split_key(key) do
    case String.split(key, "/", parts: 2) do
      [skill, rest] -> {skill, rest}
      [single] -> {"_other", single}
    end
  end

  defp group_and_sort(entries) do
    entries
    |> Enum.group_by(& &1.skill)
    |> Enum.map(fn {skill, items} -> {skill, Enum.sort_by(items, & &1.key)} end)
    |> Enum.sort_by(fn {skill, _} -> skill end)
  end

  defp format_skill("marketing"), do: "Marketing strategy"
  defp format_skill("_other"), do: "Other"
  defp format_skill(skill), do: skill |> String.replace("_", " ") |> String.capitalize()

  defp format_size(size) when is_integer(size) and size < 1024, do: "#{size} B"
  defp format_size(size) when is_integer(size) and size < 1_048_576, do: "#{div(size, 1024)} KB"
  defp format_size(size) when is_integer(size), do: "#{Float.round(size / 1_048_576, 1)} MB"
  defp format_size(_), do: "—"

  defp format_timestamp(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  defp format_timestamp(_), do: ""
end
