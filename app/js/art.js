// Inline SVG illustrations from ./art. Inlined so strokes follow currentColor and the accent follows the theme.
const cache = new Map();

export async function art(name) {
  if (cache.has(name)) return cache.get(name);
  const p = fetch(`art/${name}.svg`).then((r) => (r.ok ? r.text() : "")).then((t) => (t.startsWith("<svg") || t.includes("<svg") ? t.slice(t.indexOf("<svg")) : "")).catch(() => "");
  cache.set(name, p);
  return p;
}

// Fill every [data-art] placeholder under root. Missing art leaves the placeholder empty, never broken.
export async function mountArt(root = document) {
  const els = [...root.querySelectorAll("[data-art]")];
  await Promise.all(els.map(async (el) => { const svg = await art(el.dataset.art); if (el.isConnected) { el.innerHTML = svg; el.classList.toggle("has-art", !!svg); } }));
}
