defmodule OneAgentWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Plug to set HTTP security headers on all responses.

  Provides defense-in-depth headers for an API-only backend:
  - X-Content-Type-Options: nosniff — prevents MIME-type sniffing
  - X-Frame-Options: DENY — prevents clickjacking
  - Strict-Transport-Security — enforces HTTPS (production only)
  - Referrer-Policy: strict-origin-when-cross-origin — limits referrer leakage
  - Permissions-Policy — disables unused browser features
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
    |> maybe_put_hsts()
  end

  defp maybe_put_hsts(conn) do
    endpoint_config = Application.get_env(:oneagent, OneAgentWeb.Endpoint, [])

    if Keyword.has_key?(endpoint_config, :force_ssl) do
      put_resp_header(conn, "strict-transport-security", "max-age=63072000; includeSubDomains")
    else
      conn
    end
  end
end
