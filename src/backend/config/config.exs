# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :oneagent, :scopes,
  user: [
    default: true,
    module: OneAgent.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: OneAgent.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :oneagent,
  namespace: OneAgent,
  ecto_repos: [OneAgent.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :oneagent, OneAgentWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: OneAgentWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: OneAgent.PubSub,
  live_view: [signing_salt: "w41rOJgz"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :oneagent, OneAgent.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Hammer rate limiter (ETS backend)
config :hammer,
  backend: {Hammer.Backend.ETS,
            [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# Ueberauth (Google OAuth)
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

# Cloak encryption (keys configured per environment)
config :oneagent, OneAgent.Vault,
  ciphers: [
    default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: ""}
  ]

# Oban job processing
config :oneagent, Oban,
  repo: OneAgent.Repo,
  queues: [default: 10, scheduled: 5],
  plugins: [
    {Oban.Plugins.Cron, crontab: [
      {"* * * * *", OneAgent.Workers.ScheduleChecker}
    ]}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
