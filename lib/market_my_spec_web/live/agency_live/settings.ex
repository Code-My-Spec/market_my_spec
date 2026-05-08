defmodule MarketMySpecWeb.AgencyLive.Settings do
  @moduledoc """
  Agency settings page. Two independent forms:

  - **Subdomain form** — agency owner/admin claims or changes the agency's
    unique subdomain (`<slug>.marketmyspec.com`). Validates format,
    reserved-name exclusion, and global uniqueness.
  - **Branding form** — agency owner/admin sets logo URL (HTTPS only),
    primary color, and secondary color (both `#rrggbb`).

  Mount-level authorization: only members with `:manage_account` rights
  (owner or admin) may reach this page; others are redirected to the
  agency dashboard.
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Agencies
  alias MarketMySpec.Agencies.HostResolver
  alias MarketMySpec.Authorization

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Agency Settings
        <:subtitle>Configure your agency's subdomain and branding</:subtitle>
      </.header>

      <div class="mt-8 space-y-12">
        <section>
          <h2 class="text-lg font-semibold mb-4">Subdomain</h2>
          <p class="text-sm text-base-content/60 mb-4">
            Your agency's unique address on the platform.
            Clients reach your branded surface at
            <code>&lt;subdomain&gt;.marketmyspec.com</code>.
          </p>

          <.form
            for={@subdomain_form}
            id="subdomain-form"
            data-test="subdomain-form"
            phx-submit="save_subdomain"
          >
            <.input
              field={@subdomain_form[:subdomain]}
              type="text"
              label="Subdomain"
              placeholder="acme"
              autocomplete="off"
            />

            <div class="mt-4 flex justify-end">
              <.button type="submit" phx-disable-with="Saving…">Save subdomain</.button>
            </div>
          </.form>
        </section>

        <div class="divider"></div>

        <section>
          <h2 class="text-lg font-semibold mb-4">Branding</h2>
          <p class="text-sm text-base-content/60 mb-4">
            Logo and color tokens applied to clients on your subdomain.
            Leave blank to use the platform default theme.
          </p>

          <.form
            for={@branding_form}
            id="branding-form"
            data-test="branding-form"
            phx-submit="save_branding"
          >
            <.input
              field={@branding_form[:logo_url]}
              type="text"
              label="Logo URL (HTTPS)"
              placeholder="https://your-host.example/logo.svg"
              autocomplete="off"
            />

            <.input
              field={@branding_form[:primary_color]}
              type="text"
              label="Primary color"
              placeholder="#22c55e"
              autocomplete="off"
            />

            <.input
              field={@branding_form[:secondary_color]}
              type="text"
              label="Secondary color"
              placeholder="#1d4ed8"
              autocomplete="off"
            />

            <div class="mt-4 flex justify-end">
              <.button type="submit" phx-disable-with="Saving…">Save branding</.button>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.get_user_agency_account(user) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "No agency account found")
         |> push_navigate(to: ~p"/agency")}

      agency ->
        authorize_or_redirect(socket, agency)
    end
  end

  defp authorize_or_redirect(socket, agency) do
    case Authorization.authorize(:manage_account, socket.assigns.current_scope, agency.id) do
      true -> {:ok, mount_forms(socket, agency)}
      false -> {:ok, push_navigate(socket, to: ~p"/agency")}
    end
  end

  defp mount_forms(socket, agency) do
    socket
    |> assign(:agency, agency)
    |> assign(:subdomain_form, build_subdomain_form(agency))
    |> assign(:branding_form, build_branding_form(agency))
  end

  defp build_subdomain_form(agency) do
    to_form(Account.subdomain_changeset(agency, %{}), as: :subdomain)
  end

  defp build_branding_form(agency) do
    to_form(Account.branding_changeset(agency, %{}), as: :branding)
  end

  @impl true
  def handle_event("save_subdomain", %{"subdomain" => params}, socket) do
    subdomain = Map.get(params, "subdomain", "")

    case HostResolver.claim_subdomain(socket.assigns.agency, subdomain) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Subdomain saved")
         |> assign(:agency, updated)
         |> assign(:subdomain_form, build_subdomain_form(updated))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :subdomain_form, to_form(changeset, as: :subdomain))}
    end
  end

  def handle_event("save_branding", %{"branding" => params}, socket) do
    case Agencies.update_branding(socket.assigns.agency, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Branding saved")
         |> assign(:agency, updated)
         |> assign(:branding_form, build_branding_form(updated))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :branding_form, to_form(changeset, as: :branding))}
    end
  end
end
