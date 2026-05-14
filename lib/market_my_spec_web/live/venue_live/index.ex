defmodule MarketMySpecWeb.VenueLive.Index do
  @moduledoc """
  Admin LiveView for managing engagement venues for the active account.

  Lists venues with source badge, identifier, weight, and enabled toggle.
  Provides an inline form to add new venues, edit/remove actions per row,
  and an optimistic toggle for the enabled flag.

  Route: /accounts/:id/venues
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
              <h2 class="card-title">Venues</h2>
              <button
                phx-click="toggle_add_form"
                data-test="add-venue-button"
                class="btn btn-primary btn-sm"
              >
                Add Venue
              </button>
            </div>

            <%= if @show_add_form do %>
              <form phx-submit="save_venue" phx-change="validate_venue" data-test="venue-form">
                <div class="flex gap-2 mt-4">
                  <select name="venue[source]" class="select select-bordered select-sm">
                    <option value="">Select source</option>
                    <option value="reddit">Reddit</option>
                    <option value="elixirforum">ElixirForum</option>
                  </select>
                  <input
                    type="text"
                    name="venue[identifier]"
                    placeholder="Subreddit name or category:tag"
                    class="input input-bordered input-sm flex-1"
                  />
                  <input
                    type="number"
                    name="venue[weight]"
                    placeholder="Weight (default 1.0)"
                    step="0.1"
                    class="input input-bordered input-sm w-28"
                  />
                  <button type="submit" class="btn btn-primary btn-sm">Save</button>
                  <button type="button" phx-click="cancel_add_form" class="btn btn-ghost btn-sm">
                    Cancel
                  </button>
                </div>
                <%= if @form_error do %>
                  <p class="text-error text-sm mt-1" data-test="venue-form-error"><%= @form_error %></p>
                <% end %>
              </form>
            <% end %>

            <table class="table mt-4" data-test="venues-table">
              <thead>
                <tr>
                  <th>Source</th>
                  <th>Identifier</th>
                  <th>Weight</th>
                  <th>Enabled</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for venue <- @venues do %>
                  <tr data-test={"venue-row-#{venue.id}"}>
                    <td>
                      <span class="badge badge-outline" data-test="venue-source">
                        <%= venue.source %>
                      </span>
                    </td>
                    <td data-test="venue-identifier"><%= venue.identifier %></td>
                    <td data-test="venue-weight"><%= venue.weight %></td>
                    <td>
                      <input
                        type="checkbox"
                        checked={venue.enabled}
                        phx-click="toggle_enabled"
                        phx-value-id={venue.id}
                        data-test={"venue-enabled-toggle-#{venue.id}"}
                        class="toggle toggle-sm"
                      />
                    </td>
                    <td>
                      <button
                        phx-click="delete_venue"
                        phx-value-id={venue.id}
                        data-test={"venue-delete-#{venue.id}"}
                        class="btn btn-ghost btn-xs text-error"
                      >
                        Remove
                      </button>
                    </td>
                  </tr>
                <% end %>
                <%= if @venues == [] do %>
                  <tr>
                    <td colspan="5" class="text-center text-base-content/50" data-test="venues-empty">
                      No venues configured. Add one above.
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
        venues = Engagements.list_venues(current_scope)

        {:ok,
         socket
         |> assign(:account, account)
         |> assign(:venues, venues)
         |> assign(:show_add_form, false)
         |> assign(:form_error, nil)}
    end
  end

  @impl true
  def handle_event("toggle_add_form", _params, socket) do
    {:noreply, assign(socket, :show_add_form, !socket.assigns.show_add_form)}
  end

  def handle_event("cancel_add_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_form, false)
     |> assign(:form_error, nil)}
  end

  def handle_event("validate_venue", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_venue", %{"venue" => venue_params}, socket) do
    source = Map.get(venue_params, "source", "")
    identifier = Map.get(venue_params, "identifier", "")
    weight = parse_weight(Map.get(venue_params, "weight", "1.0"))

    cond do
      source == "" ->
        {:noreply, assign(socket, :form_error, "Source is required")}

      identifier == "" ->
        {:noreply, assign(socket, :form_error, "Identifier is required")}

      not valid_identifier?(source, identifier) ->
        {:noreply, assign(socket, :form_error, validation_error(source, identifier))}

      true ->
        attrs = %{source: source, identifier: identifier, weight: weight, enabled: true}

        case Engagements.create_venue(socket.assigns.current_scope, attrs) do
          {:ok, venue} ->
            {:noreply,
             socket
             |> assign(:venues, socket.assigns.venues ++ [venue])
             |> assign(:show_add_form, false)
             |> assign(:form_error, nil)
             |> put_flash(:info, "Venue added successfully")}

          {:error, changeset} ->
            error_message = changeset_error_message(changeset)

            {:noreply, assign(socket, :form_error, error_message)}
        end
    end
  end

  def handle_event("toggle_enabled", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    scope = socket.assigns.current_scope

    current_enabled =
      socket.assigns.venues
      |> Enum.find(fn v -> v.id == id end)
      |> case do
        nil -> true
        venue -> venue.enabled
      end

    case Engagements.update_venue(scope, id, %{enabled: !current_enabled}) do
      {:ok, updated_venue} ->
        venues =
          Enum.map(socket.assigns.venues, fn venue ->
            if venue.id == id, do: updated_venue, else: venue
          end)

        {:noreply, assign(socket, :venues, venues)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not update venue")}
    end
  end

  def handle_event("delete_venue", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    scope = socket.assigns.current_scope

    case Engagements.delete_venue(scope, id) do
      {:ok, _venue} ->
        venues = Enum.reject(socket.assigns.venues, fn venue -> venue.id == id end)

        {:noreply,
         socket
         |> assign(:venues, venues)
         |> put_flash(:info, "Venue removed")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Venue not found")}
    end
  end

  # --- Private helpers ----------------------------------------------------

  defp parse_weight(weight_str) when is_binary(weight_str) do
    case Float.parse(weight_str) do
      {float, _} -> float
      :error -> 1.0
    end
  end

  defp parse_weight(_), do: 1.0

  defp valid_identifier?("reddit", identifier) do
    # Subreddit names: letters, numbers, underscores, 3-21 chars
    Regex.match?(~r/^[a-zA-Z0-9_]{3,21}$/, identifier)
  end

  defp valid_identifier?("elixirforum", _identifier), do: true
  defp valid_identifier?(_source, _identifier), do: false

  defp validation_error("reddit", identifier) do
    "Invalid subreddit name '#{identifier}': must be 3-21 characters, letters, numbers, underscores only"
  end

  defp validation_error(source, _identifier) do
    "Unknown source '#{source}'"
  end

  defp changeset_error_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _opts}} -> "#{field} #{message}" end)
    |> Enum.join(", ")
  end
end
