defmodule OneAgent.Tools.UrlValidator.SsrfSafeReq do
  @moduledoc """
  Provides Req options for SSRF-safe HTTP requests.

  Pins connections to a pre-resolved IP address to prevent DNS rebinding,
  and validates redirect targets against the SSRF blocklist.
  """

  @max_redirects 5

  @doc """
  Returns Req options that pin the connection to a resolved IP and validate redirects.

  The returned keyword list has three keys:
  - `:url` — the URL rewritten to use the resolved IP
  - `:connect_opts` — connect options to set the correct Host/SNI
  - `:redirect_opts` — disables built-in redirects; use `safe_redirect_step/0` instead

  ## Example

      opts = SsrfSafeReq.pinned_req_options("https://example.com/path", "93.184.216.34")
      Req.get(opts[:url], opts[:connect_opts] ++ opts[:redirect_opts])
  """
  def pinned_req_options(original_url, resolved_ip) do
    uri = URI.parse(original_url)
    original_host = uri.host

    # Rewrite URL to connect to the resolved IP
    pinned_uri = %{uri | host: resolved_ip}
    pinned_url = URI.to_string(pinned_uri)

    connect_opts =
      if original_host != resolved_ip do
        [connect_options: [hostname: original_host]]
      else
        []
      end

    [
      url: pinned_url,
      connect_opts: connect_opts,
      redirect_opts: [redirect: false, max_redirects: 0]
    ]
  end

  @doc """
  Follows redirects safely, validating each redirect target against the SSRF blocklist.

  Accepts the original response from a Req call with redirects disabled.
  Returns `{:ok, response}` or `{:error, reason}`.
  """
  def follow_redirects_safely(response, req_opts, remaining \\ @max_redirects)

  def follow_redirects_safely(%Req.Response{status: status}, _req_opts, 0)
      when status in [301, 302, 303, 307, 308] do
    {:error, "Too many redirects (max #{@max_redirects})"}
  end

  def follow_redirects_safely(%Req.Response{status: status} = response, req_opts, remaining)
      when status in [301, 302, 303, 307, 308] do
    case Req.Response.get_header(response, "location") do
      [location | _] ->
        follow_redirect(location, req_opts, remaining)

      [] ->
        {:ok, response}
    end
  end

  def follow_redirects_safely(response, _req_opts, _remaining) do
    {:ok, response}
  end

  defp follow_redirect(location, req_opts, remaining) do
    # Resolve relative URLs against the current request URL
    base_url = req_opts[:url] || ""
    redirect_url = URI.merge(base_url, location) |> URI.to_string()

    # Validate and resolve the redirect target
    case OneAgent.Tools.UrlValidator.validate_and_resolve(redirect_url) do
      {:ok, resolved_ip} ->
        pinned = pinned_req_options(redirect_url, resolved_ip)

        # Merge original opts (headers, timeout, etc.) with new pinned opts
        merged_opts =
          req_opts
          |> Keyword.drop([:url, :connect_options, :redirect, :max_redirects, :method])
          |> Keyword.merge(
            url: pinned[:url],
            redirect: false,
            max_redirects: 0
          )
          |> Keyword.merge(pinned[:connect_opts])

        case Req.get(merged_opts) do
          {:ok, redirect_response} ->
            follow_redirects_safely(redirect_response, Keyword.put(merged_opts, :url, redirect_url), remaining - 1)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, "Redirect blocked: #{reason}"}
    end
  end
end
