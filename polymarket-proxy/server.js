/**
 * Minimal reverse proxy for Polymarket APIs.
 * Deployed on Fly.io in a non-US region to bypass geo-restrictions.
 *
 * Path routing:
 *   /gamma/* → gamma-api.polymarket.com/*
 *   /clob/*  → clob.polymarket.com/*
 *   /data/*  → data-api.polymarket.com/*
 */
const http = require("http");
const https = require("https");
const { URL } = require("url");

const TARGETS = {
  "/gamma": "https://gamma-api.polymarket.com",
  "/clob": "https://clob.polymarket.com",
  "/data": "https://data-api.polymarket.com",
};

const PROXY_SECRET = process.env.PROXY_SECRET;

const server = http.createServer((req, res) => {
  // Optional shared-secret gate
  if (PROXY_SECRET && req.headers["x-proxy-secret"] !== PROXY_SECRET) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  // Match path prefix to target
  let targetBase, strippedPath;
  for (const [prefix, base] of Object.entries(TARGETS)) {
    if (req.url === prefix || req.url.startsWith(prefix + "/") || req.url.startsWith(prefix + "?")) {
      targetBase = base;
      strippedPath = req.url.slice(prefix.length) || "/";
      break;
    }
  }

  if (!targetBase) {
    res.writeHead(404);
    res.end("Not Found — use /gamma/*, /clob/*, or /data/*");
    return;
  }

  const target = new URL(targetBase);
  // strippedPath includes query string already (e.g. "/order?market=123")
  const targetPath = strippedPath.startsWith("/") ? strippedPath : "/" + strippedPath;

  // Forward all headers, fix Host
  const headers = { ...req.headers };
  headers.host = target.hostname;
  delete headers["x-proxy-secret"];
  // Remove hop-by-hop headers
  delete headers["connection"];
  delete headers["transfer-encoding"];

  const options = {
    hostname: target.hostname,
    port: 443,
    path: targetPath,
    method: req.method,
    headers,
  };

  const proxy = https.request(options, (proxyRes) => {
    // Copy response headers
    const respHeaders = { ...proxyRes.headers };
    // Remove transfer-encoding to avoid chunked issues
    delete respHeaders["transfer-encoding"];

    res.writeHead(proxyRes.statusCode, respHeaders);
    proxyRes.pipe(res, { end: true });
  });

  proxy.on("error", (err) => {
    console.error("Proxy error:", err.message);
    res.writeHead(502);
    res.end("Bad Gateway");
  });

  req.pipe(proxy, { end: true });
});

const PORT = process.env.PORT || 8080;
server.listen(PORT, "0.0.0.0", () => {
  console.log(`Polymarket proxy listening on :${PORT}`);
});
