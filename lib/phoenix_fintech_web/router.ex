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

  pipeline :require_authenticated_user do
    plug :require_authenticated_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhoenixFintechWeb do
    pipe_through :browser

    get "/", PageController, :home

    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    delete "/users/log_out", UserSessionController, :delete

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings/profile", UserSettingsController, :update_profile
    put "/users/settings/password", UserSettingsController, :update_password
  end


  scope "/", PhoenixFintechWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/app", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhoenixFintechWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phoenix_fintech, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:browser, :require_authenticated_user]

      live_dashboard "/dashboard", metrics: PhoenixFintechWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
