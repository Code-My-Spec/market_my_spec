defmodule MarketMySpecWeb.SearchLive.Index do
  @moduledoc """
  Admin LiveView for managing saved engagement searches for the active account.

  Lists saved searches with name, query (truncated), venue count, and per-row
  "Run now", "Edit", and "Delete" actions. Provides an inline form to create
  or edit a search: name input, Google-syntax query string, venue picker
  (multi-select against the account's existing venues), and per-source
  wildcard checkboxes.

  Route: /accounts/:id/searches
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Engagements

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mt-6">
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Saved Searches</h2>
              <button
                phx-click="toggle_add_form"
                data-test="add-search-button"
                class="btn btn-primary btn-sm"
              >
                Add Search
              </button>
            </div>

            <%= if @show_form do %>
              <form
                phx-submit="save_search"
                phx-change="validate_search"
                data-test="search-form"
                class="mt-4 space-y-3"
              >
                <input type="hidden" name="search[id]" value={@editing_id || ""} />
                <div class="flex flex-col gap-2">
                  <input
                    type="text"
                    name="search[name]"
                    value={@form_name}
                    placeholder="Search name"
                    class="input input-bordered input-sm w-full"
                    data-test="search-name-input"
                  />
                  <input
                    type="text"
                    name="search[query]"
                    value={@form_query}
                    placeholder="Google-style query (e.g. elixir AND testing)"
                    class="input input-bordered input-sm w-full"
                    data-test="search-query-input"
                  />
                  <div>
                    <label class="label label-text text-sm font-medium">Venues (select specific venues)</label>
                    <select
                      name="search[venue_ids][]"
                      multiple
                      class="select select-bordered select-sm w-full h-32"
                      data-test="search-venue-picker"
                    >
                      <%= for venue <- @available_venues do %>
                        <option
                          value={venue.id}
                          selected={venue.id in @selected_venue_ids}
                        >
                          <%= venue.source %> — <%= venue.identifier %>
                        </option>
                      <% end %>
                    </select>
                  </div>
                  <div>
                    <label class="label label-text text-sm font-medium">Source wildcards (all venues of this source)</label>
                    <div class="flex gap-4" data-test="source-wildcards">
                      <label class="flex items-center gap-1 cursor-pointer">
                        <input
                          type="checkbox"
                          name="search[source_wildcards][]"
                          value="reddit"
                          checked={"reddit" in @selected_wildcards}
                          class="checkbox checkbox-sm"
                          data-test="wildcard-reddit"
                        />
                        <span class="text-sm">Reddit (all)</span>
                      </label>
                      <label class="flex items-center gap-1 cursor-pointer">
                        <input
                          type="checkbox"
                          name="search[source_wildcards][]"
                          value="elixirforum"
                          checked={"elixirforum" in @selected_wildcards}
                          class="checkbox checkbox-sm"
                          data-test="wildcard-elixirforum"
                        />
                        <span class="text-sm">ElixirForum (all)</span>
                      </label>
                    </div>
                  </div>
                  <div class="flex gap-2">
                    <button type="submit" class="btn btn-primary btn-sm" data-test="search-form-submit">
                      Save
                    </button>
                    <button
                      type="button"
                      phx-click="cancel_form"
                      class="btn btn-ghost btn-sm"
                      data-test="search-form-cancel"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
                <%= if @form_error do %>
                  <p class="text-error text-sm mt-1" data-test="search-form-error"><%= @form_error %></p>
                <% end %>
              </form>
            <% end %>

            <table class="table mt-4" data-test="searches-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Query</th>
                  <th>Venues</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for search <- @searches do %>
                  <tr data-test={"search-row-#{search.id}"}>
                    <td data-test="search-name"><%= search.name %></td>
                    <td data-test="search-query"><%= truncate_query(search.query) %></td>
                    <td data-test="search-venue-count"><%= length(search.venues) %></td>
                    <td>
                      <div class="flex gap-1">
                        <button
                          phx-click="run_search"
                          phx-value-id={search.id}
                          data-test={"search-run-#{search.id}"}
                          class="btn btn-ghost btn-xs"
                        >
                          Run now
                        </button>
                        <button
                          phx-click="edit_search"
                          phx-value-id={search.id}
                          data-test={"search-edit-#{search.id}"}
                          class="btn btn-ghost btn-xs"
                        >
                          Edit
                        </button>
                        <button
                          phx-click="delete_search"
                          phx-value-id={search.id}
                          data-test={"search-delete-#{search.id}"}
                          class="btn btn-ghost btn-xs text-error"
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                  <%= if @run_results[search.id] do %>
                    <tr data-test={"search-results-#{search.id}"}>
                      <td colspan="4">
                        <div class="bg-base-200 rounded p-3 mt-1">
                          <p class="text-sm font-medium mb-2">
                            Results: <%= length(@run_results[search.id].candidates) %> candidate(s)
                          </p>
                          <%= if @run_results[search.id].candidates == [] do %>
                            <p class="text-sm text-base-content/50">No candidates found.</p>
                          <% else %>
                            <ul class="space-y-1">
                              <%= for candidate <- @run_results[search.id].candidates do %>
                                <li class="text-sm">
                                  <a
                                    href={Map.get(candidate, "url") || Map.get(candidate, :url, "#")}
                                    target="_blank"
                                    class="link link-primary"
                                  >
                                    <%= Map.get(candidate, "title") || Map.get(candidate, :title, "Untitled") %>
                                  </a>
                                </li>
                              <% end %>
                            </ul>
                          <% end %>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
                <%= if @searches == [] do %>
                  <tr>
                    <td
                      colspan="4"
                      class="text-center text-base-content/50"
                      data-test="searches-empty"
                    >
                      No saved searches yet. Add one above.
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_scope = socket.assigns.current_scope

    case Accounts.get_account(current_scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Account not found")
         |> redirect(to: "/accounts")}

      account ->
        searches = Engagements.list_saved_searches(current_scope)
        venues = Engagements.list_venues(current_scope)

        {:ok,
         socket
         |> assign(:account, account)
         |> assign(:searches, searches)
         |> assign(:available_venues, venues)
         |> assign(:show_form, false)
         |> assign(:editing_id, nil)
         |> assign(:form_name, "")
         |> assign(:form_query, "")
         |> assign(:selected_venue_ids, [])
         |> assign(:selected_wildcards, [])
         |> assign(:form_error, nil)
         |> assign(:run_results, %{})}
    end
  end

  @impl true
  def handle_event("toggle_add_form", _params, socket) do
    socket =
      if socket.assigns.show_form do
        reset_form(socket)
      else
        socket
        |> assign(:show_form, true)
        |> assign(:editing_id, nil)
        |> assign(:form_name, "")
        |> assign(:form_query, "")
        |> assign(:selected_venue_ids, [])
        |> assign(:selected_wildcards, [])
        |> assign(:form_error, nil)
      end

    {:noreply, socket}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply, reset_form(socket)}
  end

  def handle_event("validate_search", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("edit_search", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    scope = socket.assigns.current_scope

    case Engagements.get_saved_search(scope, id) do
      {:ok, search} ->
        wildcards = Enum.map(search.source_wildcards || [], &Atom.to_string/1)
        venue_ids = Enum.map(search.venues || [], & &1.id)

        {:noreply,
         socket
         |> assign(:show_form, true)
         |> assign(:editing_id, id)
         |> assign(:form_name, search.name)
         |> assign(:form_query, search.query)
         |> assign(:selected_venue_ids, venue_ids)
         |> assign(:selected_wildcards, wildcards)
         |> assign(:form_error, nil)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Search not found")}
    end
  end

  def handle_event("save_search", %{"search" => params}, socket) do
    scope = socket.assigns.current_scope

    name = Map.get(params, "name", "")
    query = Map.get(params, "query", "")
    venue_id_strings = Map.get(params, "venue_ids", [])
    wildcard_strings = Map.get(params, "source_wildcards", [])

    venue_ids = Enum.map(List.wrap(venue_id_strings), &String.to_integer/1)
    wildcards = Enum.map(List.wrap(wildcard_strings), &String.to_atom/1)

    editing_id_str = Map.get(params, "id", "")

    attrs = %{
      name: name,
      query: query,
      venue_ids: venue_ids,
      source_wildcards: wildcards
    }

    result =
      if editing_id_str != "" do
        Engagements.update_saved_search(scope, String.to_integer(editing_id_str), attrs)
      else
        Engagements.create_saved_search(scope, attrs)
      end

    case result do
      {:ok, _saved_search} ->
        searches = Engagements.list_saved_searches(scope)

        {:noreply,
         socket
         |> assign(:searches, searches)
         |> reset_form()
         |> put_flash(:info, "Search saved successfully")}

      {:error, changeset} ->
        error_message = changeset_error_message(changeset)
        {:noreply, assign(socket, :form_error, error_message)}
    end
  end

  def handle_event("run_search", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    scope = socket.assigns.current_scope

    case Engagements.run_saved_search(scope, id) do
      {:ok, results} ->
        run_results = Map.put(socket.assigns.run_results, id, results)
        {:noreply, assign(socket, :run_results, run_results)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Search not found")}
    end
  end

  def handle_event("delete_search", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    scope = socket.assigns.current_scope

    case Engagements.delete_saved_search(scope, id) do
      {:ok, _search} ->
        searches = Enum.reject(socket.assigns.searches, fn s -> s.id == id end)
        run_results = Map.delete(socket.assigns.run_results, id)

        {:noreply,
         socket
         |> assign(:searches, searches)
         |> assign(:run_results, run_results)
         |> put_flash(:info, "Search deleted")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Search not found")}
    end
  end

  # --- Private helpers ----------------------------------------------------

  defp reset_form(socket) do
    socket
    |> assign(:show_form, false)
    |> assign(:editing_id, nil)
    |> assign(:form_name, "")
    |> assign(:form_query, "")
    |> assign(:selected_venue_ids, [])
    |> assign(:selected_wildcards, [])
    |> assign(:form_error, nil)
  end

  defp truncate_query(nil), do: ""

  defp truncate_query(query) when byte_size(query) > 60 do
    String.slice(query, 0, 57) <> "..."
  end

  defp truncate_query(query), do: query

  defp changeset_error_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _opts}} -> "#{field} #{message}" end)
    |> Enum.join(", ")
  end
end
