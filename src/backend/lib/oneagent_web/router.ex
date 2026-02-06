defmodule OneAgentWeb.Router do
  use OneAgentWeb, :router

  import OneAgentWeb.UserAuth

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_current_scope_for_api_user
  end

  pipeline :rate_limited do
    plug OneAgentWeb.Plugs.RateLimit, max_requests: 5, interval_ms: 60_000
  end

  # Public auth routes (no auth required, rate limited)
  scope "/api/auth", OneAgentWeb do
    pipe_through [:api, :rate_limited]

    post "/register", UserRegistrationController, :create
    post "/login", UserSessionController, :create
    post "/magic-link", UserSessionController, :send_magic_link
    post "/magic-link/verify", UserSessionController, :verify_magic_link
    post "/forgot-password", UserPasswordResetController, :create
    post "/reset-password", UserPasswordResetController, :update
    post "/confirm/:token", UserConfirmationController, :confirm
  end

  # Google OAuth routes
  scope "/api/auth", OneAgentWeb do
    pipe_through :api

    get "/google", GoogleAuthController, :request
    get "/google/callback", GoogleAuthController, :callback
  end

  # Authenticated routes
  scope "/api/auth", OneAgentWeb do
    pipe_through [:api, :require_authenticated_user]

    delete "/logout", UserSessionController, :delete
    get "/me", UserSessionController, :me
    put "/password", UserSessionController, :update_password
  end

  # Health check
  scope "/api", OneAgentWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:oneagent, :dev_routes) do
    scope "/dev" do
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
