defmodule OneAgentWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug using Hammer with ETS backend.

  Options:
    - `:max_requests` — max allowed requests per interval (default 5)
    - `:interval_ms` — interval window in milliseconds (default 60_000)
    - `:by` — `:ip` (default) or `:user` (uses authenticated user ID)
    - `:bucket_prefix` — custom prefix for the rate limit bucket (default: request path)
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    limit = Keyword.get(opts, :max_requests, 5)
    interval_ms = Keyword.get(opts, :interval_ms, 60_000)
    by = Keyword.get(opts, :by, :ip)
    prefix = Keyword.get(opts, :bucket_prefix, conn.request_path)

    key = rate_limit_key(conn, by)
    bucket = "#{prefix}:#{key}"

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

  defp rate_limit_key(conn, :user) do
    case conn.assigns[:current_scope] do
      %{user: %{id: user_id}} when not is_nil(user_id) ->
        "user:#{user_id}"

      _ ->
        # Fall back to IP if user not yet resolved
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  defp rate_limit_key(conn, :ip) do
    conn.remote_ip |> :inet.ntoa() |> to_string()
  end
end
