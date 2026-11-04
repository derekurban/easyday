// Phone dev loop over Tailscale: finds Derek's Pixel on the tailnet, connects adb, pins it to port 5555, and starts
// tool/dev.mjs on it, so hot reload works on any network without a cable.
//
//   node tool/phone.mjs [start [PORT]]    connect and start the dev loop on 127.0.0.1:5182 (detached; prints when ready)
//   node tool/phone.mjs connect [PORT]    connect adb only and print the serial
//   node tool/phone.mjs pair PORT CODE    one-time pairing (Wireless debugging > Pair device with pairing code)
//   node tool/phone.mjs reload|restart    ship the current code to the phone (hot reload keeps the screen, restart resets);
//                                         starts the loop first if it died, which installs the current code anyway
//   node tool/phone.mjs status            tailnet, adb and dev loop state
//   node tool/phone.mjs stop              stop the phone dev loop
//
// The phone needs Tailscale on. After a reboot it also needs Wireless debugging on once: its port is random, so this
// scans for it, then runs `adb tcpip 5555` so later connects (and mobile data) go straight to 5555 until the next reboot.
// PHONE_HOST overrides the address, DEV_PORT the dev loop port (5182, so it never collides with an emulator loop on 5181).
import { execFileSync, spawn } from "node:child_process";
import { openSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import net from "node:net";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const host = process.env.PHONE_HOST ?? "100.68.165.42"; // dereks-pixel on the tailnet
const fixedPort = 5555;
const serial = `${host}:${fixedPort}`;
const devPort = Number(process.env.DEV_PORT ?? 5182);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const adb = (...args) => {
  try { return execFileSync("adb", args, { encoding: "utf8", timeout: 30000, stdio: ["ignore", "pipe", "pipe"] }).trim(); }
  catch (e) { return `${e.stdout ?? ""}${e.stderr ?? ""}`.trim() || String(e.message); }
};
const state = (s) => adb("-s", s, "get-state");
const online = (s) => state(s) === "device";

const reachable = (port, timeout = 1500) => new Promise((r) => {
  const s = net.connect({ host, port });
  const done = (ok) => { s.destroy(); r(ok); };
  s.setTimeout(timeout); s.on("connect", () => done(true)); s.on("error", () => done(false)); s.on("timeout", () => done(false));
});

// Closed ports on the phone drop packets rather than refuse, so every probe waits for its timeout. More than ~300
// probes in flight over Tailscale starts losing the open ports too, so this takes a couple of minutes: pass the port
// shown under Wireless debugging (`connect PORT`) to skip it.
async function scan(lo = 32768, hi = 60999) {
  const open = []; let next = lo;
  await Promise.all(Array.from({ length: 300 }, async () => { while (next <= hi) { const p = next++; if (await reachable(p, 1500)) open.push(p); } }));
  return open.sort((a, b) => a - b);
}

async function tailnet() {
  try { execFileSync("tailscale", ["ping", "-c", "1", "--timeout", "5s", host], { stdio: "ignore", timeout: 10000 }); return true; }
  catch { return false; }
}

async function connect(port) {
  if (online(serial)) return serial;
  if (!(await tailnet())) throw new Error(`phone not reachable on Tailscale (${host}): open Tailscale on the phone`);
  if (await reachable(fixedPort)) {
    adb("connect", serial);
    for (let i = 0; i < 10 && !online(serial); i++) await sleep(500);
    if (online(serial)) return serial;
  }
  // Wireless debugging's own connection: adb 37 finds it by mDNS on the same Wi-Fi; elsewhere it is the given port or a scan.
  const tls = adb("devices").split(/\r?\n/).filter((l) => /_adb-tls-connect\._tcp\s+device$/.test(l)).map((l) => l.split(/\s+/)[0]);
  for (const s of tls) if (await pin(s)) return serial;
  if (!port) console.error("port 5555 closed: scanning for the Wireless debugging port (~2 min; pass the port to skip)...");
  const ports = port ? [Number(port)] : (await scan()).filter((p) => p !== fixedPort);
  for (const p of ports) {
    const s = `${host}:${p}`;
    adb("connect", s);
    for (let i = 0; i < 6 && !online(s); i++) await sleep(500);
    if (!online(s)) { adb("disconnect", s); continue; }
    if (await pin(s)) return serial;
  }
  throw new Error(ports.length
    ? `no authorised adb port among ${ports.join(", ")}: pair first (node tool/phone.mjs pair PORT CODE)`
    : "no adb port open: turn on Developer options > Wireless debugging on the phone");
}

// Restart the phone's adbd on the fixed port (until reboot), then connect to it over Tailscale.
async function pin(s) {
  adb("-s", s, "tcpip", String(fixedPort));
  for (let i = 0; i < 20; i++) {
    await sleep(1000);
    adb("connect", serial);
    if (online(serial)) return true;
  }
  console.error(`switched ${s} to tcpip ${fixedPort} but could not reconnect`);
  return false;
}

const dev = async (p, ms = 5000) => {
  try { return await (await fetch(`http://127.0.0.1:${devPort}${p}`, { signal: AbortSignal.timeout(ms) })).json(); }
  catch (e) { return e.name === "TimeoutError" ? { pending: true } : null; }
};

async function start(port) {
  const s = await connect(port);
  console.log(`adb: ${s}`);
  const st = await dev("/status");
  if (st?.running && !st.pending) { console.log(`dev loop already running on ${devPort}: ${JSON.stringify(st)}`); return; }
  mkdirSync(path.join(root, "build"), { recursive: true });
  const out = openSync(path.join(root, "build", "phone-dev.out"), "w");
  const child = spawn(process.execPath, [path.join(root, "tool", "dev.mjs"), s], {
    cwd: root, detached: true, stdio: ["ignore", out, out], windowsHide: true, env: { ...process.env, DEV_PORT: String(devPort) },
  });
  child.unref();
  console.log(`dev loop starting on 127.0.0.1:${devPort} (log: curl localhost:${devPort}/log?tail=40)`);
  for (let i = 0; i < 600; i++) {
    await sleep(2000);
    const st = await dev("/status");
    if (st?.ready) { console.log("ready: app running on the phone"); return; }
    if (i > 5 && !st) throw new Error(`dev loop exited: see build/phone-dev.out and build/dev.log`);
  }
  throw new Error("dev loop not ready after 20 minutes");
}

const [cmd = "start", ...rest] = process.argv.slice(2);
try {
  if (cmd === "start") await start(rest[0]);
  else if (cmd === "connect") console.log(await connect(rest[0]));
  else if (cmd === "reload" || cmd === "restart") {
    if (!(await dev("/status"))?.ready) await start(); // a fresh run installs the current code: nothing left to ship
    else {
      // The new code is on the phone within seconds, but the rebuild waits for a frame, and a backgrounded app draws none:
      // then the change shows the moment Derek opens Easyday Dev. flutter run queues later reloads behind it.
      const r = await dev(`/${cmd}`, 20000);
      if (r?.pending) console.log(`${cmd} sent: Easyday Dev is in the background, the change shows when it is opened`);
      else if (!r || r.error || r.code) throw new Error(`${cmd} failed: ${JSON.stringify(r)} (curl localhost:${devPort}/log?tail=40)`);
      else console.log(`${cmd}ed on the phone in ${r.ms} ms`);
    }
  } else if (cmd === "pair") {
    const [port, code] = rest;
    if (!port || !code) throw new Error("usage: node tool/phone.mjs pair PORT CODE");
    console.log(adb("pair", `${host}:${port}`, code));
  } else if (cmd === "status") {
    console.log(JSON.stringify({ host, tailnet: await tailnet(), adb: state(serial), dev: await dev("/status") }));
  } else if (cmd === "stop") console.log(JSON.stringify(await dev("/stop") ?? { running: false }));
  else throw new Error(`unknown command: ${cmd}`);
} catch (e) { console.error(String(e.message ?? e)); process.exit(1); }
