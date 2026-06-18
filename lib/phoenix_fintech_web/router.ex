defmodule PhoenixFintechWeb.Router do
  use PhoenixFintechWeb, :router

  import PhoenixFintechWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixFintechWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :authenticated do
    plug :require_authenticated_user
  end

  pipeline :admin do
    plug :require_admin_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhoenixFintechWeb do
    pipe_through :browser

    get "/", PageController, :home

    get "/users/sign_up", UserRegistrationController, :new
    post "/users/sign_up", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    delete "/users/log_out", UserSessionController, :delete
  end

  scope "/", PhoenixFintechWeb do
    pipe_through [:browser, :authenticated]

    get "/app", PageController, :home

    live_session :authenticated,
      on_mount: [
        {PhoenixFintechWeb.UserAuth, :mount_current_scope},
        {PhoenixFintechWeb.UserAuth, :assign_notifications_unread_count}
      ] do
      live "/app/parties", PartyIndexLive
      live "/app/parties/new", OriginatorOnboardingLive
      live "/app/parties/:id", PartyShowLive, :overview
      live "/app/parties/:id/members", PartyShowLive, :members
      live "/app/parties/:id/documents", PartyShowLive, :documents
      live "/app/transfers", TransferIndexLive
      live "/app/transfers/new", TransferNewLive
      live "/app/transfers/:id", TransferShowLive
      live "/app/notifications", NotificationsLive, :index
    end

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings/profile", UserSettingsController, :update_profile
    put "/users/settings/password", UserSettingsController, :update_password
  end

  scope "/admin", PhoenixFintechWeb do
    pipe_through [:browser, :authenticated, :admin]

    live_session :admin,
      on_mount: [
        {PhoenixFintechWeb.UserAuth, :mount_current_scope},
        {PhoenixFintechWeb.UserAuth, :require_admin}
      ] do
      live "/", AdminLive, :index
      live "/compliance_reviews", ComplianceReviewLive, :index
      live "/compliance_reviews/:id", ComplianceReviewLive, :show
      live "/:resource", AdminLive, :resource
      live "/:resource/:id/edit", AdminLive, :edit
    end
  end

  # Other scopes may use custom stacks.
  scope "/api", PhoenixFintechWeb do
    pipe_through :api

    put "/mock_s3/objects", MockS3Controller, :put_object
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phoenix_fintech, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:browser, :authenticated]

      live_dashboard "/dashboard", metrics: PhoenixFintechWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
