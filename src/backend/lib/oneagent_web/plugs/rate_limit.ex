defmodule OneAgentWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug using Hammer with ETS backend, keyed by IP.
  5 requests per minute on auth endpoints.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    limit = Keyword.get(opts, :max_requests, 5)
    interval_ms = Keyword.get(opts, :interval_ms, 60_000)

    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    bucket = "#{conn.request_path}:#{ip}"

    case Hammer.check_rate(bucket, interval_ms, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{error: "Too many requests. Please try again later."}))
        |> halt()
    end
  end
end
