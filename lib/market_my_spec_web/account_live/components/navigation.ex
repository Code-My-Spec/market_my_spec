defmodule MarketMySpecWeb.AccountLive.Components.Navigation do
  @moduledoc """
  LiveComponent rendering the account settings navigation tabs.
  """

  use MarketMySpecWeb, :live_component

  alias MarketMySpec.Authorization

  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@account.name}
        <:subtitle>Account settings and member management</:subtitle>
      </.header>

      <div class="mt-8">
        <div class="tabs tabs-boxed">
          <.link
            patch={~p"/accounts/#{@account.id}/manage"}
            class={["tab", if(@active_tab == :manage, do: "tab-active")]}
          >
            Manage
          </.link>
          <.link
            patch={~p"/accounts/#{@account.id}/members"}
            class={["tab", if(@active_tab == :members, do: "tab-active")]}
          >
            Members
          </.link>
          <.link
            :if={can_manage_members?(@current_scope, @account)}
            patch={~p"/accounts/#{@account.id}/invitations"}
            class={["tab", if(@active_tab == :invitations, do: "tab-active")]}
          >
            Invitations
          </.link>
          <.link
            :if={agency_account?(@account)}
            data-test="nav-agency-dashboard"
            navigate={~p"/agency"}
            class={["tab", if(@active_tab == :agency_dashboard, do: "tab-active")]}
          >
            Agency Dashboard
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp can_manage_members?(scope, account) do
    Authorization.authorize(:manage_members, scope, account.id)
  end

  defp agency_account?(account) do
    account.type == :agency
  end
end
