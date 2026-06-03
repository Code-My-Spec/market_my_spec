defmodule MarketMySpecWeb.LinterLive.StyleGuide do
  @moduledoc """
  Account-scoped style-guide settings.

  Paste a Vale `.vale.ini` body into the textarea and submit; on success it
  is persisted on the account. Submitting a malformed body surfaces the
  validation error from `vale ls-config` and leaves any prior config
  untouched. The "Clear configuration" action removes the saved body.

  Route: `/accounts/:account_id/style-guide`
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Linter

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mt-6">
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <h2 class="card-title">Style Guide</h2>

            <p class="text-sm text-base-content/70">
              {style_guide_intro(@vale_ini)}
            </p>

            <form
              phx-submit="save_style_guide"
              data-test="style-guide-form"
              class="mt-4"
            >
              <textarea
                name="style_guide[vale_ini]"
                rows="14"
                class="textarea textarea-bordered w-full font-mono text-sm"
                placeholder="Paste your .vale.ini here..."
              ><%= @form_value %></textarea>

              <%= if @validation_error do %>
                <p
                  class="text-error text-sm mt-2"
                  data-test="style-guide-error"
                >
                  Vale config validation error: {@validation_error}
                </p>
              <% end %>

              <div class="flex gap-2 mt-3">
                <button type="submit" class="btn btn-primary btn-sm">Save</button>
                <%= if @vale_ini do %>
                  <button
                    type="button"
                    phx-click="clear_style_guide"
                    data-test="clear-style-guide"
                    class="btn btn-ghost btn-sm text-error"
                  >
                    Clear configuration
                  </button>
                <% end %>
              </div>
            </form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"account_id" => account_id}, _session, socket) do
    current_scope = socket.assigns.current_scope

    case Accounts.get_account(current_scope, account_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Account not found")
         |> redirect(to: "/app/accounts")}

      _account ->
        vale_ini = load_config(current_scope)

        {:ok,
         socket
         |> assign(:vale_ini, vale_ini)
         |> assign(:form_value, vale_ini || "")
         |> assign(:validation_error, nil)}
    end
  end

  @impl true
  def handle_event(
        "save_style_guide",
        %{"style_guide" => %{"vale_ini" => vale_ini}},
        socket
      ) do
    case Linter.save_config(socket.assigns.current_scope, vale_ini) do
      {:ok, _config} ->
        {:noreply,
         socket
         |> assign(:vale_ini, vale_ini)
         |> assign(:form_value, vale_ini)
         |> assign(:validation_error, nil)
         |> put_flash(:info, "Style guide saved.")}

      {:error, error_text} when is_binary(error_text) ->
        {:noreply,
         socket
         |> assign(:form_value, vale_ini)
         |> assign(:validation_error, error_text)
         |> put_flash(:error, "Invalid Vale configuration. Save rejected.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:form_value, vale_ini)
         |> assign(:validation_error, "could not persist configuration")
         |> put_flash(:error, "Could not save configuration.")}
    end
  end

  def handle_event("clear_style_guide", _params, socket) do
    :ok = Linter.clear_config(socket.assigns.current_scope)

    {:noreply,
     socket
     |> assign(:vale_ini, nil)
     |> assign(:form_value, "")
     |> assign(:validation_error, nil)
     |> put_flash(:info, "Style guide cleared.")}
  end

  defp load_config(scope) do
    case Linter.get_config(scope) do
      {:ok, vale_ini} -> vale_ini
      {:error, :no_config} -> nil
    end
  end

  defp style_guide_intro(nil) do
    "Paste a Vale .vale.ini below to enable prose linting on your polished comments. No configuration saved yet."
  end

  defp style_guide_intro(_vale_ini) do
    "Your saved Vale configuration. Replace it by pasting a new .vale.ini below, or clear it to disable linting."
  end
end
