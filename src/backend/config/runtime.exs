import Config

if System.get_env("PHX_SERVER") do
  config :oneagent, OneAgentWeb.Endpoint, server: true
end

config :oneagent, OneAgentWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# CORS origin (defaults to localhost:3000 for dev)
if cors_origin = System.get_env("CORS_ORIGIN") do
  config :oneagent, cors_origin: cors_origin
end

# Google OAuth credentials (optional in dev)
if client_id = System.get_env("GOOGLE_CLIENT_ID") do
  config :ueberauth, Ueberauth.Strategy.Google.OAuth,
    client_id: client_id,
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
end

# Cloak encryption key (required in prod, optional in dev/test)
if cloak_key = System.get_env("CLOAK_KEY") do
  config :oneagent, OneAgent.Vault,
    ciphers: [
      default: {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1",
       key: Base.decode64!(cloak_key)}
    ]
end

# Email allowlist (comma-separated, optional)
if allowed = System.get_env("ALLOWED_EMAILS") do
  emails =
    allowed
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&(&1 == ""))

  config :oneagent, :allowed_emails, emails
end

# Configurable email from address
if email_from = System.get_env("EMAIL_FROM") do
  config :oneagent, :email_from, email_from
end

# Frontend URL for email links
if frontend_url = System.get_env("FRONTEND_URL") do
  config :oneagent, :frontend_url, frontend_url
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :oneagent, OneAgent.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # Require CLOAK_KEY in production for credential encryption
  unless System.get_env("CLOAK_KEY") do
    raise """
    environment variable CLOAK_KEY is missing.
    Credentials will not be encrypted without it.
    Generate one with: elixir -e "IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))"
    """
  end

  host = System.get_env("PHX_HOST") || "example.com"

  config :oneagent, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :oneagent, OneAgentWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # Resend email adapter for production
  if resend_key = System.get_env("RESEND_API_KEY") do
    config :oneagent, OneAgent.Mailer,
      adapter: Swoosh.Adapters.Resend,
      api_key: resend_key
  end
end
