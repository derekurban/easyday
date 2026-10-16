// Dev loop: keeps `flutter run --machine` alive and exposes it over HTTP so an agent (or a shell) can
// hot-reload, hot-restart, read the log, and stop it without an interactive terminal.
//
//   node tool/dev.mjs [deviceId]          start (default device: emulator-5554), listens on 127.0.0.1:5181
//   curl localhost:5181/reload            hot reload (keeps state)
//   curl localhost:5181/restart           hot restart (resets state)
//   curl localhost:5181/log?tail=80       last N log lines
//   curl localhost:5181/status            { running, appId, ready }
//   curl localhost:5181/stop              quit flutter run and exit
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { writeFileSync, appendFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const device = process.argv[2] ?? "emulator-5554";
const port = Number(process.env.DEV_PORT ?? 5181);
const logFile = path.join(root, "build", "dev.log");
try { writeFileSync(logFile, ""); } catch {}

const lines = [];
const log = (s) => { for (const l of String(s).split(/\r?\n/)) { if (!l) continue; lines.push(l); if (lines.length > 2000) lines.shift(); try { appendFileSync(logFile, l + "\n"); } catch {} } };

const flutter = process.platform === "win32" ? "flutter.bat" : "flutter";
const child = spawn(flutter, ["run", "--machine", "-d", device], { cwd: root, stdio: ["pipe", "pipe", "pipe"], shell: process.platform === "win32" });

let appId = null, ready = false, nextId = 1;
const pending = new Map();
const send = (method, params = {}) => new Promise((res, rej) => {
  const id = nextId++;
  pending.set(id, { res, rej });
  child.stdin.write(JSON.stringify([{ id, method, params }]) + "\n");
  setTimeout(() => { if (pending.delete(id)) rej(new Error(`timeout: ${method}`)); }, 120000);
});

let buf = "";
child.stdout.on("data", (d) => {
  buf += d.toString();
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i).trim(); buf = buf.slice(i + 1);
    if (!line) continue;
    if (line.startsWith("[") && line.endsWith("]")) {
      let msgs; try { msgs = JSON.parse(line); } catch { log(line); continue; }
      for (const m of msgs) {
        if (m.event === "app.start") { appId = m.params.appId; log(`[dev] app.start ${appId}`); }
        else if (m.event === "app.started") { ready = true; log("[dev] app.started"); }
        else if (m.event === "app.log") log(m.params.log);
        else if (m.event === "app.progress") { if (m.params.message) log(`[dev] ${m.params.message}`); }
        else if (m.event === "daemon.logMessage") log(`[daemon] ${m.params.level}: ${m.params.message}`);
        else if (m.id != null && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result); }
        else log(`[event] ${JSON.stringify(m)}`);
      }
    } else log(line);
  }
});
child.stderr.on("data", (d) => log(`[stderr] ${d}`));
child.on("exit", (code) => { log(`[dev] flutter exited ${code}`); setTimeout(() => process.exit(code ?? 0), 200); });

const server = createServer(async (req, res) => {
  const url = new URL(req.url, "http://x");
  const reply = (code, body) => { res.writeHead(code, { "content-type": "application/json" }); res.end(JSON.stringify(body)); };
  try {
    if (url.pathname === "/status") return reply(200, { running: child.exitCode == null, appId, ready, device });
    if (url.pathname === "/log") { const n = Number(url.searchParams.get("tail") ?? 60); res.writeHead(200, { "content-type": "text/plain" }); return res.end(lines.slice(-n).join("\n") + "\n"); }
    if (url.pathname === "/reload" || url.pathname === "/restart") {
      if (!appId) return reply(409, { error: "app not started yet" });
      const t0 = Date.now();
      const r = await send("app.restart", { appId, fullRestart: url.pathname === "/restart", reason: "manual", pause: false });
      return reply(200, { ...r, ms: Date.now() - t0 });
    }
    if (url.pathname === "/stop") { reply(200, { ok: true }); if (appId) { try { await send("app.stop", { appId }); } catch {} } child.kill(); setTimeout(() => process.exit(0), 500); return; }
    reply(404, { error: "unknown", routes: ["/status", "/log?tail=N", "/reload", "/restart", "/stop"] });
  } catch (e) { reply(500, { error: String(e.message ?? e) }); }
});
server.listen(port, "127.0.0.1", () => log(`[dev] listening on http://127.0.0.1:${port} device=${device}`));
