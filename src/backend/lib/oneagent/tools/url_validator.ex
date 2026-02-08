defmodule OneAgent.Tools.UrlValidator do
  @moduledoc """
  Validates URLs for outbound HTTP requests to prevent SSRF attacks.
  Blocks private/internal IP ranges, cloud metadata endpoints, and non-HTTP schemes.

  Uses DNS resolution at validation time and returns the resolved IP to prevent
  DNS rebinding (TOCTOU) attacks.
  """

  @blocked_hosts ~w(localhost metadata.google.internal metadata.google)

  @doc """
  Validates a URL for safe outbound use. Returns `:ok` or `{:error, reason}`.

  NOTE: This does NOT protect against DNS rebinding. Prefer `validate_and_resolve/1`
  which pins the resolved IP.
  """
  def validate(url) when is_binary(url) do
    case validate_url_structure(url) do
      {:ok, _host} -> :ok
      {:error, _} = err -> err
    end
  end

  def validate(_), do: {:error, "URL must be a string"}

  @doc """
  Validates a URL and resolves its hostname to an IP address.
  Returns `{:ok, resolved_ip}` where `resolved_ip` is a string like "93.184.216.34",
  or `{:error, reason}`.

  The caller should use the resolved IP for the actual connection to prevent
  DNS rebinding attacks (where the DNS record changes between validation and connection).
  """
  def validate_and_resolve(url) when is_binary(url) do
    with {:ok, host} <- validate_url_structure(url) do
      resolve_and_check(host)
    end
  end

  def validate_and_resolve(_), do: {:error, "URL must be a string"}

  @doc """
  Checks a resolved IP address tuple against blocked ranges.
  Used to re-validate redirect targets.
  """
  def check_ip(ip_tuple) do
    if private_ip_tuple?(ip_tuple) do
      {:error, "Requests to private/internal IP addresses are not allowed"}
    else
      :ok
    end
  end

  # Validates URL structure (scheme, host, blocked hosts, direct IP literals).
  # Returns {:ok, host} on success.
  defp validate_url_structure(url) do
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
            {:ok, host}
        end
    end
  end

  # Resolves a hostname via DNS and checks the resolved IP against blocked ranges.
  defp resolve_and_check(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, ip_tuple} ->
        # Host is already an IP literal — just return it
        {:ok, format_ip(ip_tuple)}

      {:error, :einval} ->
        # Host is a hostname — resolve it
        case :inet.getaddr(String.to_charlist(host), :inet) do
          {:ok, ip_tuple} ->
            if private_ip_tuple?(ip_tuple) do
              {:error, "Requests to private/internal IP addresses are not allowed"}
            else
              {:ok, format_ip(ip_tuple)}
            end

          {:error, reason} ->
            {:error, "DNS resolution failed for #{host}: #{inspect(reason)}"}
        end
    end
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip(ipv6) when tuple_size(ipv6) == 8 do
    ipv6
    |> Tuple.to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.join(":")
  end

  defp ip_address?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp private_ip?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, tuple} -> private_ip_tuple?(tuple)
      _ -> false
    end
  end

  defp private_ip_tuple?({127, _, _, _}), do: true
  defp private_ip_tuple?({10, _, _, _}), do: true
  defp private_ip_tuple?({172, b, _, _}) when b >= 16 and b <= 31, do: true
  defp private_ip_tuple?({192, 168, _, _}), do: true
  defp private_ip_tuple?({169, 254, _, _}), do: true
  defp private_ip_tuple?({0, _, _, _}), do: true
  # IPv6 loopback (::1)
  defp private_ip_tuple?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  # IPv6 unspecified (::)
  defp private_ip_tuple?({0, 0, 0, 0, 0, 0, 0, 0}), do: true
  # IPv6-mapped IPv4 (::ffff:x.x.x.x) — extract embedded IPv4 and re-check
  defp private_ip_tuple?({0, 0, 0, 0, 0, 0xFFFF, ab, cd}) do
    private_ip_tuple?(
      {Bitwise.bsr(ab, 8), Bitwise.band(ab, 0xFF), Bitwise.bsr(cd, 8), Bitwise.band(cd, 0xFF)}
    )
  end
  # IPv6 link-local (fe80::/10)
  defp private_ip_tuple?({w, _, _, _, _, _, _, _}) when w >= 0xFE80 and w <= 0xFEBF, do: true
  # IPv6 unique-local (fc00::/7)
  defp private_ip_tuple?({w, _, _, _, _, _, _, _}) when w >= 0xFC00 and w <= 0xFDFF, do: true
  defp private_ip_tuple?(_), do: false
end
