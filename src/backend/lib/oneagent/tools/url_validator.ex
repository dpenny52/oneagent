defmodule OneAgent.Tools.UrlValidator do
  @moduledoc """
  Validates URLs for outbound HTTP requests to prevent SSRF attacks.
  Blocks private/internal IP ranges, cloud metadata endpoints, and non-HTTP schemes.
  """

  @blocked_hosts ~w(localhost metadata.google.internal metadata.google)

  @doc """
  Validates a URL for safe outbound use. Returns `:ok` or `{:error, reason}`.
  """
  def validate(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme} when scheme not in ["http", "https"] ->
        {:error, "URL must use http or https scheme, got: #{scheme || "none"}"}

      %URI{host: host} when host in [nil, ""] ->
        {:error, "URL must include a host"}

      %URI{host: host} ->
        host = String.downcase(host)

        cond do
          host in @blocked_hosts ->
            {:error, "Requests to #{host} are not allowed"}

          ip_address?(host) && private_ip?(host) ->
            {:error, "Requests to private/internal IP addresses are not allowed"}

          true ->
            :ok
        end
    end
  end

  def validate(_), do: {:error, "URL must be a string"}

  defp ip_address?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp private_ip?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, {127, _, _, _}} -> true
      {:ok, {10, _, _, _}} -> true
      {:ok, {172, b, _, _}} when b >= 16 and b <= 31 -> true
      {:ok, {192, 168, _, _}} -> true
      {:ok, {169, 254, _, _}} -> true
      {:ok, {0, 0, 0, 0}} -> true
      # IPv6 loopback (::1)
      {:ok, {0, 0, 0, 0, 0, 0, 0, 1}} -> true
      # IPv6 unspecified (::)
      {:ok, {0, 0, 0, 0, 0, 0, 0, 0}} -> true
      # IPv6-mapped IPv4 (::ffff:x.x.x.x) — extract embedded IPv4 and re-check
      {:ok, {0, 0, 0, 0, 0, 0xFFFF, ab, cd}} ->
        private_ipv4?(Bitwise.bsr(ab, 8), Bitwise.band(ab, 0xFF), Bitwise.bsr(cd, 8), Bitwise.band(cd, 0xFF))
      # IPv6 link-local (fe80::/10)
      {:ok, {w, _, _, _, _, _, _, _}} when w >= 0xFE80 and w <= 0xFEBF -> true
      # IPv6 unique-local (fc00::/7)
      {:ok, {w, _, _, _, _, _, _, _}} when w >= 0xFC00 and w <= 0xFDFF -> true
      _ -> false
    end
  end

  defp private_ipv4?(a, _b, _c, _d) when a == 127, do: true
  defp private_ipv4?(a, _b, _c, _d) when a == 10, do: true
  defp private_ipv4?(a, b, _c, _d) when a == 172 and b >= 16 and b <= 31, do: true
  defp private_ipv4?(a, b, _c, _d) when a == 192 and b == 168, do: true
  defp private_ipv4?(a, b, _c, _d) when a == 169 and b == 254, do: true
  defp private_ipv4?(a, b, c, d) when a == 0 and b == 0 and c == 0 and d == 0, do: true
  defp private_ipv4?(_a, _b, _c, _d), do: false
end
