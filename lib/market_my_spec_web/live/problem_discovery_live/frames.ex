defmodule MarketMySpecWeb.ProblemDiscoveryLive.Frames do
  @moduledoc """
  Frames index + compose surface (story 742).

  Founder-direct entry point for Frame composition. Lists the account's
  existing Frames and renders a form for creating new ones with the four
  required components: description, saved searches, money_gate threshold
  (total_spent_min + hire_rate_min), and kill_condition
  (min_money_gated_candidates).
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.ProblemDiscovery

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:frames, ProblemDiscovery.list_frames(socket.assigns.current_scope))
     |> assign(:form, build_form())}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :live_action, socket.assigns.live_action)}
  end

  @impl true
  def handle_event("validate", %{"frame" => params}, socket) do
    {:noreply, assign(socket, :form, build_form(params))}
  end

  @impl true
  def handle_event("save", %{"frame" => params}, socket) do
    attrs = parse_attrs(params)

    case ProblemDiscovery.create_frame(socket.assigns.current_scope, attrs) do
      {:ok, frame} ->
        {:noreply,
         socket
         |> put_flash(:info, "Frame created.")
         |> push_navigate(to: ~p"/problem-discovery/frames/#{frame.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create Frame: #{format_errors(changeset)}")
         |> assign(:form, to_form(changeset, as: "frame"))}
    end
  end

  defp build_form(params \\ %{}) do
    defaults = %{
      "title" => "",
      "description" => "",
      "saved_searches_text" => "",
      "total_spent_min" => "5000",
      "hire_rate_min" => "50",
      "min_money_gated_candidates" => "3"
    }

    to_form(Map.merge(defaults, params), as: "frame")
  end

  defp parse_attrs(params) do
    %{
      title: Map.get(params, "title", "") |> String.trim(),
      description: Map.get(params, "description", "") |> String.trim(),
      saved_searches: parse_saved_searches(Map.get(params, "saved_searches_text", "")),
      money_gate: %{
        total_spent_min: parse_int(Map.get(params, "total_spent_min")),
        hire_rate_min: parse_int(Map.get(params, "hire_rate_min"))
      },
      kill_condition: %{
        min_money_gated_candidates: parse_int(Map.get(params, "min_money_gated_candidates"))
      }
    }
  end

  defp parse_saved_searches(text) when is_binary(text) do
    text
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_saved_search_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_saved_search_line(line) do
    case String.split(line, ":", parts: 2) do
      [source, query] -> %{source: String.trim(source), query: String.trim(query)}
      _ -> nil
    end
  end

  defp parse_int(nil), do: 0
  defp parse_int(""), do: 0
  defp parse_int(s) when is_binary(s), do: String.to_integer(String.trim(s))
  defp parse_int(n) when is_integer(n), do: n

  defp format_errors(%Ecto.Changeset{errors: errors}) do
    Enum.map_join(errors, "; ", fn {f, {msg, _}} -> "#{f} #{msg}" end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl py-12">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-semibold">Problem Discovery Frames</h1>
          <.link
            :if={@live_action != :new}
            navigate={~p"/problem-discovery/frames/new"}
            class="btn btn-primary btn-sm"
          >
            New Frame
          </.link>
        </div>

        <div :if={@live_action == :new} class="mt-8 rounded-lg border border-base-300 p-6">
          <h2 class="text-lg font-medium mb-4">Compose a new Frame</h2>
          <.form for={@form} phx-change="validate" phx-submit="save" data-test="frame-form">
            <div class="space-y-4">
              <div>
                <label class="label">Title (short label, ≤80 chars)</label>
                <input
                  type="text"
                  name="frame[title]"
                  value={@form[:title].value}
                  maxlength="256"
                  class="input input-bordered w-full"
                  placeholder="Vendor onboarding pain"
                />
              </div>
              <div>
                <label class="label">Description (full hypothesis, 1-3 sentences)</label>
                <textarea
                  name="frame[description]"
                  rows="3"
                  class="textarea textarea-bordered w-full"
                  placeholder="Agencies migrating sub-accounts after acquisition. The handoff is repetitive enough that someone is already paying freelancers to do it manually — the question is whether that's a service play or a productizable wedge."
                ><%= @form[:description].value %></textarea>
              </div>

              <div>
                <label class="label">Saved searches (one per line, "source: query")</label>
                <textarea
                  name="frame[saved_searches_text]"
                  rows="5"
                  class="textarea textarea-bordered w-full font-mono text-sm"
                  placeholder={"upwork: vendor onboarding migration\nupwork: supplier portal consolidation\nupwork: agency sub-account intake"}
                ><%= @form[:saved_searches_text].value %></textarea>
                <p class="text-xs text-base-content/60 mt-1">
                  At least 3 distinct framings (per anti-pattern 2 of the research).
                </p>
              </div>

              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="label">total_spent_min ($)</label>
                  <input
                    type="number"
                    name="frame[total_spent_min]"
                    value={@form[:total_spent_min].value}
                    class="input input-bordered w-full"
                  />
                </div>
                <div>
                  <label class="label">hire_rate_min (%)</label>
                  <input
                    type="number"
                    name="frame[hire_rate_min]"
                    value={@form[:hire_rate_min].value}
                    class="input input-bordered w-full"
                  />
                </div>
              </div>

              <div>
                <label class="label">kill_condition: min_money_gated_candidates</label>
                <input
                  type="number"
                  name="frame[min_money_gated_candidates]"
                  value={@form[:min_money_gated_candidates].value}
                  class="input input-bordered w-full"
                />
                <p class="text-xs text-base-content/60 mt-1">
                  Pre-commit: if fewer than N money-gated Candidates emerge, this is a NO.
                </p>
              </div>

              <div class="flex justify-end gap-2">
                <.link navigate={~p"/problem-discovery/frames"} class="btn btn-ghost">Cancel</.link>
                <button type="submit" class="btn btn-primary">Commit Frame</button>
              </div>
            </div>
          </.form>
        </div>

        <%= if @frames == [] and @live_action != :new do %>
          <div class="mt-8 rounded-lg border border-base-300 p-6 text-base-content/70">
            <p>No Frames yet.</p>
            <p class="mt-2 text-sm">
              Start by composing a Frame: a fuzzy hypothesis, saved searches in observed market vocabulary, your money-gate threshold, and your kill_condition.
            </p>
          </div>
        <% else %>
          <ul class="mt-8 space-y-3" data-test="frames-list">
            <li
              :for={frame <- @frames}
              class="rounded-lg border border-base-300 p-4"
              data-test="frame-row"
            >
              <.link
                navigate={~p"/problem-discovery/frames/#{frame.id}"}
                class="block"
              >
                <p class="font-medium truncate">{frame.title || frame.description}</p>
                <p :if={frame.title} class="text-sm text-base-content/70 mt-1 line-clamp-2">
                  {frame.description}
                </p>
                <p class="text-xs text-base-content/60 mt-1">
                  {length(frame.saved_searches)} saved searches
                </p>
              </.link>
            </li>
          </ul>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
