defmodule MarketMySpecWeb.Router do
  use MarketMySpecWeb, :router

  import MarketMySpecWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MarketMySpecWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :mcp_authenticated do
    plug :accepts, ["json", "sse"]
    plug MarketMySpecWeb.Plugs.RequireMcpToken
  end

  # Well-known OAuth metadata endpoints (public, no session required)
  scope "/", MarketMySpecWeb do
    pipe_through :api

    get "/.well-known/oauth-protected-resource", OauthController, :protected_resource_metadata
    get "/.well-known/oauth-authorization-server", OauthController, :authorization_server_metadata
  end

  # OAuth token/revoke/register endpoints (public API, bearer auth inside)
  scope "/", MarketMySpecWeb do
    pipe_through :api

    post "/oauth/token", OauthController, :token
    post "/oauth/revoke", OauthController, :revoke
    post "/oauth/register", OauthController, :register
  end

  # MCP server — bearer-authenticated, delegates to Anubis via McpController
  scope "/mcp", MarketMySpecWeb do
    pipe_through :mcp_authenticated

    match :*, "/", McpController, :handle
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:market_my_spec, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MarketMySpecWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", MarketMySpecWeb do
    pipe_through [:browser, :require_authenticated_user]

    # Account creation route — requires authentication but NOT an existing account membership.
    # Users land here immediately after first sign-up.
    live_session :require_authenticated_user_no_account_check,
      on_mount: [{MarketMySpecWeb.UserAuth, :require_authenticated}] do
      live "/accounts/new", AccountLive.Form, :new
    end

    # Agency routes — requires authentication, account membership, AND an agency-typed account.
    live_session :require_agency_account,
      on_mount: [
        {MarketMySpecWeb.UserAuth, :require_authenticated},
        {MarketMySpecWeb.UserAuth, :require_account_membership},
        {MarketMySpecWeb.UserAuth, :require_agency_account}
      ] do
      live "/agency", AgencyLive.Dashboard, :index
      live "/agency/clients/new", AgencyLive.ClientNew, :new
      live "/agency/settings", AgencyLive.Settings, :edit
    end

    # All other authenticated routes — requires authentication AND at least one account membership.
    live_session :require_authenticated_user,
      on_mount: [
        {MarketMySpecWeb.UserAuth, :require_authenticated},
        {MarketMySpecWeb.UserAuth, :require_account_membership}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/integrations", IntegrationLive.Index, :index

      live "/accounts", AccountLive.Index, :index
      live "/accounts/picker", AccountLive.Picker, :index
      live "/accounts/:id", AccountLive.Manage, :show
      live "/accounts/:id/manage", AccountLive.Manage, :show
      live "/accounts/:id/members", AccountLive.Members, :show
      live "/accounts/:id/invitations", InvitationsLive.Index, :index
      live "/accounts/:id/venues", VenueLive.Index, :index
      live "/accounts/:id/searches", SearchLive.Index, :index
      live "/accounts/:id/threads", ThreadLive.Index, :index
      live "/accounts/:account_id/threads/:thread_id", ThreadLive.Show, :show
      live "/accounts/:account_id/touchpoints", TouchpointLive.Index, :index
      live "/accounts/:account_id/touchpoints/:touchpoint_id", TouchpointLive.Show, :show

      live "/files", FilesLive.Browser, :index
      live "/files/*key", FilesLive.Browser, :show

      live "/mcp-setup", McpSetupLive, :index

      live "/oauth/authorize", McpAuthorizationLive, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/integrations/oauth", MarketMySpecWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/:provider", IntegrationsController, :request
    get "/callback/:provider", IntegrationsController, :callback
  end

  # Public Google/GitHub sign-in routes (no authentication required)
  scope "/auth", MarketMySpecWeb do
    pipe_through :browser

    get "/:provider", UserOAuthController, :request
    get "/:provider/callback", UserOAuthController, :callback
  end

  scope "/", MarketMySpecWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {MarketMySpecWeb.UserAuth, :mount_current_scope},
        {MarketMySpecWeb.UserAuth, :fetch_current_agency}
      ] do
      live "/", HomeLive, :index
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/invitations/accept/:token", InvitationsLive.Accept, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
