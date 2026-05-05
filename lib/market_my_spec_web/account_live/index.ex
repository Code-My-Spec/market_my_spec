defmodule MarketMySpecWeb.AccountLive.Index do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Accounts.Invitation
  alias MarketMySpec.Authorization
  alias MarketMySpec.Users

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Your Accounts
        <:subtitle>Manage your accounts</:subtitle>
      </.header>

      <%!-- Inside-client indicator — shown when the user has entered a client context
            from the agency dashboard. --%>
      <div
        :if={@active_client_account}
        data-test="inside-client-indicator"
        class="mt-4 p-3 rounded-lg bg-info/10 border border-info/30 flex items-center gap-2"
      >
        <.icon name="hero-building-office" class="size-4 text-info" />
        <span class="text-sm">
          Operating inside client: <strong>{@active_client_account.name}</strong>
        </span>
      </div>

      <div class="mt-8 space-y-6">
        <div :if={Enum.any?(@accounts)} class="space-y-4">
          <div class="grid grid-cols-1 gap-6">
            <div
              :for={{account, index} <- Enum.with_index(@accounts)}
              data-test="account-row"
              class="card bg-base-100 border border-base-300"
            >
              <div class="card-body">
                <div class="flex items-start justify-between">
                  <div>
                    <h2 data-test="current-account" class="card-title text-base">{account.name}</h2>
                    <p class="text-sm text-base-content/70">
                      {account.slug}
                    </p>
                    <div class="flex items-center gap-2 mt-1">
                      <span
                        :if={account.role}
                        class="badge badge-outline badge-sm"
                      >
                        {String.capitalize(to_string(account.role))}
                      </span>
                      <span
                        data-test={"account-type-#{account.type}"}
                        class="badge badge-ghost badge-sm"
                      >
                        {String.capitalize(to_string(account.type))}
                      </span>
                    </div>
                  </div>
                  <div class="flex gap-2">
                    <.link
                      :if={account.type == :agency}
                      data-test="nav-agency-dashboard"
                      navigate={~p"/agency"}
                      class="btn btn-sm btn-ghost"
                    >
                      Agency Dashboard
                    </.link>
                    <.button navigate={~p"/accounts/#{account}/members"} class="btn-sm btn-ghost">
                      Members
                    </.button>
                    <.button navigate={~p"/accounts/#{account}"} class="btn-sm">
                      Manage
                    </.button>
                  </div>
                </div>

                <%!-- Pending invitations for this account --%>
                <div
                  :if={can_manage_members?(@current_scope, account) && Enum.any?(pending_invitations_for(@pending_invitations, account.id))}
                  class="mt-4 border-t border-base-300 pt-4"
                >
                  <h3 class="text-sm font-semibold mb-2">Pending Invitations</h3>
                  <ul class="space-y-1">
                    <li
                      :for={invitation <- pending_invitations_for(@pending_invitations, account.id)}
                      class="flex items-center justify-between text-sm"
                    >
                      <span>{invitation.email}</span>
                      <span class="badge badge-outline badge-xs">
                        {String.capitalize(to_string(invitation.role))}
                      </span>
                    </li>
                  </ul>
                </div>

                <%!-- Inline invite form — shown only for the first (most recently created) account
                      where the current user can manage members. Accounts are ordered newest-first,
                      so index == 0 is the user's most recent account. --%>
                <.invite_form_section
                  :if={index == 0 && can_manage_members?(@current_scope, account)}
                  account={account}
                  form={invite_form_for(@invite_forms, account.id)}
                />

                <%!-- Grant agency access form — shown for individual accounts where the user is owner.
                      Allows a client to grant an agency access to their account. --%>
                <.grant_agency_form_section
                  :if={index == 0 && account.type == :individual && can_manage_members?(@current_scope, account)}
                  account={account}
                  form={grant_form_for(@grant_forms, account.id)}
                />
              </div>
            </div>
          </div>
        </div>

        <div :if={Enum.empty?(@accounts) && !@show_create_form} class="text-center py-12">
          <p class="text-base-content/70 mb-4">You don't have any accounts yet.</p>
        </div>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <div :if={!@show_create_form} class="text-center">
              <h3 class="text-lg font-semibold mb-2">Create Account</h3>
              <p class="text-sm text-base-content/70 mb-4">
                Create an account to start collaborating
              </p>
              <.button phx-click="show-create-form">
                <.icon name="hero-plus" class="size-4 mr-2" /> Create Account
              </.button>
            </div>

            <div :if={@show_create_form} class="space-y-4">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-semibold">Create Account</h3>
                <button phx-click="show-create-form" class="btn btn-sm btn-ghost">
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </div>

              <.form
                for={@form}
                id="create-account-form"
                data-test="account-form"
                phx-change="validate"
                phx-submit="create-account"
              >
                <div class="space-y-4">
                  <.input
                    field={@form[:name]}
                    type="text"
                    label="Account Name"
                    placeholder="Enter account name"
                  />
                  <.input field={@form[:slug]} type="text" label="Slug" placeholder="account-slug" />

                  <div class="flex justify-end space-x-2">
                    <.button type="button" phx-click="show-create-form" class="btn-ghost">
                      Cancel
                    </.button>
                    <.button type="submit" phx-disable-with="Creating...">
                      Create Account
                    </.button>
                  </div>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :account, :any, required: true
  attr :form, :any, required: true

  defp invite_form_section(assigns) do
    ~H"""
    <div class="mt-4 border-t border-base-300 pt-4">
      <.form
        for={@form}
        id={"invite-form-#{@account.id}"}
        data-test="invite-member-form"
        phx-change="validate-invite"
        phx-submit="send-invitation"
        phx-value-account-id={@account.id}
      >
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <.input
            field={@form[:email]}
            id={"invite-email-#{@account.id}"}
            type="email"
            label="Invite by Email"
            placeholder="colleague@example.com"
          />
          <.input
            field={@form[:role]}
            id={"invite-role-#{@account.id}"}
            type="select"
            label="Role"
            options={[{"Member", "member"}, {"Admin", "admin"}, {"Owner", "owner"}]}
          />
        </div>
        <div class="flex justify-end mt-3">
          <.button type="submit" phx-disable-with="Sending..." class="btn-sm btn-primary">
            Send Invitation
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  attr :account, :any, required: true
  attr :form, :any, required: true

  defp grant_agency_form_section(assigns) do
    ~H"""
    <div class="mt-4 border-t border-base-300 pt-4">
      <h3 class="text-sm font-semibold mb-2">Grant Agency Access</h3>
      <p class="text-xs text-base-content/60 mb-3">
        Allow an agency to manage this account on your behalf.
      </p>
      <.form
        for={@form}
        id={"grant-agency-form-#{@account.id}"}
        data-test="grant-agency-access-form"
        phx-change="validate-grant"
        phx-submit="grant-agency-access"
        phx-value-account-id={@account.id}
      >
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <.input
            field={@form[:agency_slug]}
            id={"grant-slug-#{@account.id}"}
            type="text"
            label="Agency Slug"
            placeholder="my-agency"
          />
          <.input
            field={@form[:access_level]}
            id={"grant-level-#{@account.id}"}
            type="select"
            label="Access Level"
            options={[
              {"Read Only", "read_only"},
              {"Account Manager", "account_manager"},
              {"Admin", "admin"}
            ]}
          />
        </div>
        <div class="flex justify-end mt-3">
          <.button type="submit" phx-disable-with="Granting..." class="btn-sm btn-primary">
            Grant Access
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope
    accounts = Accounts.list_accounts(current_scope)
    pending_invitations = load_pending_invitations(current_scope, accounts)
    invite_forms = build_invite_forms(accounts)
    grant_forms = build_grant_forms(accounts)

    # Reload the user from DB to get the freshest active_client_account_id
    fresh_user = Users.get_user!(current_scope.user.id)
    active_client_account = Accounts.get_active_client_account(fresh_user)

    # Subscribe to account and invitation updates
    Phoenix.PubSub.subscribe(MarketMySpec.PubSub, "accounts:#{current_scope.user.id}")

    {:ok,
     socket
     |> assign(:accounts, accounts)
     |> assign(:pending_invitations, pending_invitations)
     |> assign(:invite_forms, invite_forms)
     |> assign(:grant_forms, grant_forms)
     |> assign(:show_create_form, false)
     |> assign(:active_client_account, active_client_account)
     |> assign(:form, to_form(Account.create_changeset(%{})))}
  end

  @impl true
  def handle_event("show-create-form", _params, socket) do
    {:noreply, assign(socket, :show_create_form, !socket.assigns.show_create_form)}
  end

  def handle_event("create-account", %{"account" => account_params}, socket) do
    case Accounts.create_account(socket.assigns.current_scope, account_params) do
      {:ok, _account} ->
        accounts = Accounts.list_accounts(socket.assigns.current_scope)
        pending_invitations = load_pending_invitations(socket.assigns.current_scope, accounts)
        invite_forms = build_invite_forms(accounts)
        grant_forms = build_grant_forms(accounts)

        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully")
         |> assign(:accounts, accounts)
         |> assign(:pending_invitations, pending_invitations)
         |> assign(:invite_forms, invite_forms)
         |> assign(:grant_forms, grant_forms)
         |> assign(:show_create_form, false)
         |> assign(:form, to_form(Account.create_changeset(%{})))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset = Account.create_changeset(account_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event(
        "validate-invite",
        %{"invitation" => invitation_params, "account-id" => account_id},
        socket
      ) do
    changeset = Invitation.changeset(%Invitation{}, invitation_params)

    invite_forms =
      Map.put(
        socket.assigns.invite_forms,
        account_id,
        to_form(changeset, action: :validate)
      )

    {:noreply, assign(socket, :invite_forms, invite_forms)}
  end

  def handle_event(
        "send-invitation",
        %{"invitation" => invitation_params, "account-id" => account_id},
        socket
      ) do
    email = invitation_params["email"]
    role = invitation_params["role"] |> String.to_existing_atom()

    case Accounts.invite_user(socket.assigns.current_scope, account_id, email, role) do
      {:ok, _invitation} ->
        accounts = socket.assigns.accounts
        pending_invitations = load_pending_invitations(socket.assigns.current_scope, accounts)
        invite_forms = Map.put(socket.assigns.invite_forms, account_id, fresh_invite_form())

        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}")
         |> assign(:pending_invitations, pending_invitations)
         |> assign(:invite_forms, invite_forms)}

      {:error, :user_already_member} ->
        changeset =
          %Invitation{}
          |> Invitation.changeset(invitation_params)
          |> Ecto.Changeset.add_error(:email, "User already has access to this account")

        invite_forms =
          Map.put(
            socket.assigns.invite_forms,
            account_id,
            to_form(changeset, action: :insert)
          )

        {:noreply,
         socket
         |> clear_flash()
         |> assign(:invite_forms, invite_forms)}

      {:error, :invitation_already_pending} ->
        changeset =
          %Invitation{}
          |> Invitation.changeset(invitation_params)
          |> Ecto.Changeset.add_error(:email, "An invitation is already pending for this email")

        invite_forms =
          Map.put(
            socket.assigns.invite_forms,
            account_id,
            to_form(changeset, action: :insert)
          )

        {:noreply,
         socket
         |> clear_flash()
         |> assign(:invite_forms, invite_forms)}

      {:error, :not_authorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to invite users")}

      {:error, :email_delivery_failed} ->
        {:noreply, put_flash(socket, :error, "Failed to send invitation email")}

      {:error, %Ecto.Changeset{} = changeset} ->
        invite_forms = Map.put(socket.assigns.invite_forms, account_id, to_form(changeset))
        {:noreply, assign(socket, :invite_forms, invite_forms)}
    end
  end

  def handle_event(
        "validate-grant",
        %{"grant" => grant_params, "account-id" => account_id},
        socket
      ) do
    changeset = grant_changeset(grant_params)

    grant_forms =
      Map.put(
        socket.assigns.grant_forms,
        account_id,
        to_form(changeset, as: :grant, action: :validate)
      )

    {:noreply, assign(socket, :grant_forms, grant_forms)}
  end

  def handle_event(
        "grant-agency-access",
        %{"grant" => grant_params, "account-id" => account_id},
        socket
      ) do
    current_scope = socket.assigns.current_scope
    agency_slug = grant_params["agency_slug"]
    access_level = grant_params["access_level"]

    # Find the client account from the list
    client_account =
      Enum.find(socket.assigns.accounts, fn a -> a.id == account_id end)

    case client_account do
      nil ->
        {:noreply, put_flash(socket, :error, "Account not found")}

      account ->
        case Accounts.invite_agency_grant(account, agency_slug, access_level, current_scope.user.id) do
          {:ok, _grant} ->
            grant_forms = Map.put(socket.assigns.grant_forms, account_id, fresh_grant_form())

            {:noreply,
             socket
             |> put_flash(:info, "Agency access granted successfully")
             |> assign(:grant_forms, grant_forms)}

          {:error, :already_granted} ->
            changeset =
              grant_changeset(grant_params)
              |> Ecto.Changeset.add_error(
                :agency_slug,
                "already has access — this agency already has access to this account"
              )

            grant_forms =
              Map.put(
                socket.assigns.grant_forms,
                account_id,
                to_form(changeset, as: :grant, action: :insert)
              )

            {:noreply, assign(socket, :grant_forms, grant_forms)}

          {:error, :agency_not_found} ->
            changeset =
              grant_changeset(grant_params)
              |> Ecto.Changeset.add_error(:agency_slug, "no agency found with that slug")

            grant_forms =
              Map.put(
                socket.assigns.grant_forms,
                account_id,
                to_form(changeset, as: :grant, action: :insert)
              )

            {:noreply, assign(socket, :grant_forms, grant_forms)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to grant agency access")}
        end
    end
  end

  @impl true
  def handle_info({:account_updated, _account}, socket) do
    accounts = Accounts.list_accounts(socket.assigns.current_scope)
    pending_invitations = load_pending_invitations(socket.assigns.current_scope, accounts)
    {:noreply, socket |> assign(:accounts, accounts) |> assign(:pending_invitations, pending_invitations)}
  end

  def handle_info({:account_created, _account}, socket) do
    accounts = Accounts.list_accounts(socket.assigns.current_scope)
    pending_invitations = load_pending_invitations(socket.assigns.current_scope, accounts)
    invite_forms = build_invite_forms(accounts)
    grant_forms = build_grant_forms(accounts)

    {:noreply,
     socket
     |> assign(:accounts, accounts)
     |> assign(:pending_invitations, pending_invitations)
     |> assign(:invite_forms, invite_forms)
     |> assign(:grant_forms, grant_forms)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp can_manage_members?(current_scope, account) do
    Authorization.authorize(:manage_members, current_scope, account.id)
  end

  defp load_pending_invitations(scope, accounts) do
    Enum.reduce(accounts, %{}, fn account, acc ->
      invitations = Accounts.list_pending_invitations(scope, account.id)
      Map.put(acc, account.id, invitations)
    end)
  end

  defp build_invite_forms(accounts) do
    Enum.reduce(accounts, %{}, fn account, acc ->
      Map.put(acc, account.id, fresh_invite_form())
    end)
  end

  defp build_grant_forms(accounts) do
    Enum.reduce(accounts, %{}, fn account, acc ->
      Map.put(acc, account.id, fresh_grant_form())
    end)
  end

  defp fresh_invite_form do
    to_form(Invitation.changeset(%Invitation{}, %{}))
  end

  defp fresh_grant_form do
    to_form(grant_changeset(%{}), as: :grant)
  end

  defp grant_changeset(params) do
    types = %{agency_slug: :string, access_level: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:agency_slug, :access_level])
  end

  defp invite_form_for(invite_forms, account_id) do
    Map.get(invite_forms, account_id, fresh_invite_form())
  end

  defp grant_form_for(grant_forms, account_id) do
    Map.get(grant_forms, account_id, fresh_grant_form())
  end

  defp pending_invitations_for(pending_invitations, account_id) do
    Map.get(pending_invitations, account_id, [])
  end
end
