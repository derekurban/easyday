// Static file server for local development.
//   node serve.mjs                                   ->  http://localhost:5179/muscle-map/playground/
//   ROOT=docs/app-logic PORT=5180 node serve.mjs     ->  serves that folder (index.html at /)
//   HOME_PATH=/app/ PORT=5180 node serve.mjs         ->  repo root, / redirects to the app
// Binds all interfaces, so it is reachable over Tailscale at http://<tailscale-ip>:<port>/.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repo = fileURLToPath(new URL(".", import.meta.url));
const root = process.env.ROOT ? resolve(repo, process.env.ROOT) + "\\" : repo;
const port = Number(process.env.PORT ?? 5179);
const home = process.env.HOME_PATH ?? (process.env.ROOT ? "/" : "/muscle-map/playground/");
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8", ".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg", ".webp": "image/webp",
  ".svg": "image/svg+xml", ".md": "text/plain; charset=utf-8", ".mmd": "text/plain; charset=utf-8", ".webmanifest": "application/manifest+json", ".woff2": "font/woff2",
  ".apk": "application/vnd.android.package-archive", ".txt": "text/plain; charset=utf-8" };

createServer(async (req, res) => {
  let path = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (path === "/" && home !== "/") { res.writeHead(302, { location: home }); return res.end(); }
  if (path.endsWith("/")) path += "index.html";
  const file = normalize(join(root, path));
  if (!file.startsWith(root)) return res.writeHead(403).end();
  try {
    const body = await readFile(file);
    res.writeHead(200, { "content-type": types[extname(file)] ?? "application/octet-stream", "cache-control": "no-store" });
    res.end(body);
  } catch { res.writeHead(404).end("not found"); }
}).listen(port, "0.0.0.0", () => console.log(`serving ${root} on http://localhost:${port}${home}`));
