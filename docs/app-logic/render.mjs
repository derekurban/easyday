// Renders docs/app-logic/src/*.mmd to build/*.png with headless Edge and writes index.html (the site).
//   node docs/app-logic/render.mjs            # render PNGs + index
//   node docs/app-logic/render.mjs --site     # only rebuild index.html
import { readdir, readFile, writeFile, mkdir } from "node:fs/promises";
import { join, dirname, basename } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { execFileSync } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const src = join(here, "src"), build = join(here, "build");
const edge = process.env.EDGE ?? "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const WIDTH = 2400, HEIGHT = 3600;
const siteOnly = process.argv.includes("--site");
await mkdir(build, { recursive: true });

const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
const MERMAID = `<script type="module">
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
mermaid.initialize({ startOnLoad:true, theme:"neutral", flowchart:{ htmlLabels:true, curve:"basis", padding:12 } });
</script>`;

const shot = (body, width) => `<!doctype html><html><head><meta charset="utf-8">
<style>body{margin:0;padding:24px;background:#fff;font-family:Segoe UI,system-ui,sans-serif}.d{width:${width}px}</style>
${MERMAID}</head><body>${body}</body></html>`;

const files = (await readdir(src)).filter(f => f.endsWith(".mmd")).sort();
const diagrams = [];
for (const f of files) {
  const text = await readFile(join(src, f), "utf8");
  const title = /^title:\s*(.+)$/m.exec(text)?.[1] ?? f;
  const name = basename(f, ".mmd");
  diagrams.push({ name, title, text });
  if (siteOnly) continue;
  const html = join(build, `${name}.html`);
  await writeFile(html, shot(`<div class="d"><pre class="mermaid">${esc(text)}</pre></div>`, WIDTH - 48));
  execFileSync(edge, ["--headless=new", "--disable-gpu", "--hide-scrollbars", `--window-size=${WIDTH},${HEIGHT}`,
    "--virtual-time-budget=8000", `--screenshot=${join(build, `${name}.png`)}`, pathToFileURL(html).href], { stdio: "ignore" });
  console.log("rendered", name);
}

// Principles come from README.md, the bullet list under "## Design principles".
const readme = await readFile(join(here, "README.md"), "utf8");
const principlesBlock = readme.split(/^## Design principles.*$/m)[1] ?? "";
const principles = principlesBlock.split("\n").filter(l => l.startsWith("- ")).map(l => l.slice(2));
const decided = /## Design principles \(decided ([^)]+)\)/.exec(readme)?.[1] ?? "";

const nav = diagrams.map(d => `<a href="#${d.name}">${esc(d.title.split(" · ")[0])}</a>`).join("");
const sections = diagrams.map(d => `
<section id="${d.name}">
  <h2>${esc(d.title)}</h2>
  <div class="diagram"><pre class="mermaid">${esc(d.text)}</pre></div>
  <p class="meta"><a href="build/${d.name}.png">PNG</a> · <a href="src/${d.name}.mmd">source</a></p>
</section>`).join("");

const site = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fitness app · logic</title>
<style>
  :root{--fg:#1b1b1f;--muted:#6b6b76;--line:#e4e4ea;--bg:#fff;--accent:#5b4fd1}
  @media (prefers-color-scheme:dark){:root{--fg:#ececf1;--muted:#9a9aa6;--line:#2c2c34;--bg:#131316;--accent:#a89cff}}
  *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.55 Segoe UI,system-ui,sans-serif}
  header{padding:28px 20px 12px;max-width:1200px;margin:0 auto} h1{margin:0 0 4px;font-size:26px} .sub{color:var(--muted);margin:0}
  nav{position:sticky;top:0;background:var(--bg);border-bottom:1px solid var(--line);padding:8px 20px;display:flex;gap:6px;flex-wrap:wrap;z-index:1}
  nav a{color:var(--fg);text-decoration:none;padding:6px 10px;border:1px solid var(--line);border-radius:999px;font-size:14px}
  nav a:hover{border-color:var(--accent);color:var(--accent)}
  main{max-width:1200px;margin:0 auto;padding:12px 20px 60px}
  section{padding:28px 0;border-bottom:1px solid var(--line)} h2{margin:0 0 14px;font-size:20px}
  .diagram{background:#fff;border:1px solid var(--line);border-radius:10px;padding:16px;overflow:auto}
  .diagram svg{display:block;margin:0 auto}
  .meta{color:var(--muted);font-size:13px;margin:8px 0 0} .meta a{color:var(--muted)}
  ol.principles{padding-left:22px;margin:0} ol.principles li{margin:8px 0}
  footer{color:var(--muted);font-size:13px;padding:20px}
</style>${MERMAID}</head><body>
<header><h1>Fitness app · logic</h1><p class="sub">Habit-first training app. How the pieces fit, one visit, the feedback loops, person state, and automations.</p></header>
<nav><a href="#principles">Principles</a>${nav}</nav>
<main>
<section id="principles"><h2>Design principles${decided ? ` · decided ${esc(decided)}` : ""}</h2>
<ol class="principles">${principles.map(p => `<li>${esc(p)}</li>`).join("")}</ol></section>
${sections}
</main>
<footer>Sources in <code>docs/app-logic/src</code>. Rebuild with <code>node docs/app-logic/render.mjs</code>.</footer>
</body></html>`;
await writeFile(join(here, "index.html"), site);
console.log("wrote index.html");
