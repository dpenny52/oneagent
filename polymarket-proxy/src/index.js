/**
 * Cloudflare Worker — transparent reverse proxy for Polymarket APIs.
 *
 * Deployed once per API (gamma, clob, data) via wrangler environments.
 * Each environment sets TARGET_BASE to the real Polymarket origin.
 *
 * Paths are forwarded 1:1, so HMAC signatures stay valid.
 * An optional PROXY_SECRET env var can restrict access.
 */
export default {
  async fetch(request, env) {
    // Optional shared-secret gate
    if (env.PROXY_SECRET) {
      const provided = request.headers.get("X-Proxy-Secret");
      if (provided !== env.PROXY_SECRET) {
        return new Response("Forbidden", { status: 403 });
      }
    }

    const url = new URL(request.url);
    const targetUrl = env.TARGET_BASE + url.pathname + url.search;

    // Clone headers, swap Host, strip proxy-specific ones
    const headers = new Headers(request.headers);
    headers.set("Host", new URL(env.TARGET_BASE).hostname);
    headers.delete("X-Proxy-Secret");
    // Remove Cloudflare-added headers that may confuse the upstream
    headers.delete("cf-connecting-ip");
    headers.delete("cf-ipcountry");
    headers.delete("cf-ray");
    headers.delete("cf-visitor");

    const init = {
      method: request.method,
      headers,
    };

    // Forward body for methods that have one
    if (!["GET", "HEAD"].includes(request.method)) {
      init.body = request.body;
      // Preserve duplex streaming
      init.duplex = "half";
    }

    const response = await fetch(targetUrl, init);

    // Return upstream response, adding permissive CORS for our backend
    const respHeaders = new Headers(response.headers);
    respHeaders.set("Access-Control-Allow-Origin", "*");
    respHeaders.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    respHeaders.set(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization, POLY_ADDRESS, POLY_API_KEY, POLY_PASSPHRASE, POLY_TIMESTAMP, POLY_SIGNATURE, X-Proxy-Secret"
    );

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: respHeaders });
    }

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: respHeaders,
    });
  },
};
