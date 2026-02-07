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

  pipeline :webhook do
    plug :accepts, ["json"]
    plug OneAgentWeb.Plugs.RateLimit, max_requests: 60, interval_ms: 60_000
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

  # Gmail OAuth callback (public — Google redirects here)
  scope "/api/auth", OneAgentWeb do
    pipe_through :api

    get "/gmail/callback", GmailAuthController, :callback
  end

  # Authenticated routes
  scope "/api/auth", OneAgentWeb do
    pipe_through [:api, :require_authenticated_user]

    delete "/logout", UserSessionController, :delete
    get "/me", UserSessionController, :me
    put "/password", UserSessionController, :update_password
    get "/gmail", GmailAuthController, :authorize
  end

  # Authenticated API routes
  scope "/api", OneAgentWeb do
    pipe_through [:api, :require_authenticated_user]

    resources "/agents", AgentController, except: [:new, :edit] do
      post "/invoke", AgentController, :invoke
      get "/buckets", AgentController, :list_buckets
      put "/buckets", AgentController, :update_buckets
      get "/runs", AgentController, :list_runs
      get "/runs/:id", AgentController, :show_run
      get "/memory", AgentController, :list_memories
      delete "/memory", AgentController, :delete_memories
      get "/messages", AgentController, :list_messages
      delete "/messages", AgentController, :delete_messages
      get "/schedules", AgentController, :list_schedules
      post "/schedules", AgentController, :create_schedule
      put "/schedules/:id", AgentController, :update_schedule
      delete "/schedules/:id", AgentController, :delete_schedule
    end

    resources "/credentials", CredentialController, except: [:new, :edit]
    resources "/llm-configs", LlmConfigController, except: [:new, :edit]
    resources "/whatsapp-channels", WhatsAppChannelController, except: [:new, :edit]
  end

  # WhatsApp webhook (unauthenticated, rate limited)
  scope "/api/webhooks", OneAgentWeb do
    pipe_through [:webhook]

    get "/whatsapp", WhatsAppWebhookController, :verify
    post "/whatsapp", WhatsAppWebhookController, :handle
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
