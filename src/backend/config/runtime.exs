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

  host = System.get_env("PHX_HOST") || "example.com"

  config :oneagent, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :oneagent, OneAgentWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end
