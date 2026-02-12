defmodule OneAgentWeb.Plugs.RequestLogger do
  @moduledoc """
  Logs every API request and response with method, path, status, and timing.

  Sensitive params (password, token, secret, api_key, private_key, credential)
  are filtered from logged request bodies.
  """
  require Logger
  import Plug.Conn

  @filtered_keys ~w(password token secret api_key private_key credential)
  @max_body_log 1000
  @max_error_body_log 500

  def init(opts), do: opts

  def call(conn, _opts) do
    start = System.monotonic_time()

    conn
    |> put_private(:request_logger_start, start)
    |> log_request()
    |> register_before_send(&log_response(&1, start))
  end

  defp log_request(conn) do
    body_info = format_request_body(conn)

    Logger.info(fn ->
      qs = if conn.query_string != "", do: "?#{conn.query_string}", else: ""
      parts = ["API ▸ #{conn.method} #{conn.request_path}#{qs}"]
      parts = if body_info, do: parts ++ ["params=#{body_info}"], else: parts
      Enum.join(parts, " ")
    end, method: conn.method, path: conn.request_path)

    conn
  end

  defp log_response(conn, start) do
    duration = System.monotonic_time() - start
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    status = conn.status
    method = conn.method
    path = conn.request_path

    summary = "API ▸ #{method} #{path} — #{status} in #{duration_ms}ms"

    cond do
      status >= 500 ->
        Logger.error(fn ->
          "#{summary} body=#{truncate_body(conn.resp_body, @max_error_body_log)}"
        end, method: method, path: path, status: status, duration_ms: duration_ms)

      status >= 400 ->
        Logger.warning(fn ->
          "#{summary} body=#{truncate_body(conn.resp_body, @max_error_body_log)}"
        end, method: method, path: path, status: status, duration_ms: duration_ms)

      true ->
        Logger.info(fn -> summary end,
          method: method, path: path, status: status, duration_ms: duration_ms)
    end

    conn
  end

  defp format_request_body(%{method: "GET"}), do: nil
  defp format_request_body(%{method: "HEAD"}), do: nil
  defp format_request_body(%{body_params: %Plug.Conn.Unfetched{}}), do: nil

  defp format_request_body(%{body_params: params}) when params == %{}, do: nil

  defp format_request_body(%{body_params: params}) do
    params
    |> filter_sensitive()
    |> inspect(limit: :infinity, printable_limit: @max_body_log)
    |> truncate(@max_body_log)
  end

  defp filter_sensitive(params) when is_map(params) do
    Map.new(params, fn
      {key, value} when is_binary(key) ->
        if String.downcase(key) in @filtered_keys do
          {key, "[FILTERED]"}
        else
          {key, filter_sensitive(value)}
        end

      {key, value} ->
        {key, filter_sensitive(value)}
    end)
  end

  defp filter_sensitive(params) when is_list(params) do
    Enum.map(params, &filter_sensitive/1)
  end

  defp filter_sensitive(value), do: value

  defp truncate(str, max) when byte_size(str) > max do
    String.slice(str, 0, max) <> "…"
  end

  defp truncate(str, _max), do: str

  defp truncate_body(nil, _max), do: ""
  defp truncate_body(body, max) when is_binary(body), do: truncate(body, max)
  defp truncate_body(body, max) when is_list(body), do: body |> IO.iodata_to_binary() |> truncate(max)
  defp truncate_body(_body, _max), do: ""
end
