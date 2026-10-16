// Renders the shipped muscle maps (muscle-map/assets) with primary/secondary tinting.
// Pixel data is cached per sex and view; finished renders are cached per muscle set so re-renders are instant.
const A = "../muscle-map/assets/";
let meta = null;
const cache = {};
const rendered = new Map();

const loadImg = (src) => new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = src; });
function pixels(img) {
  const c = document.createElement("canvas"); c.width = img.width; c.height = img.height;
  const x = c.getContext("2d", { willReadFrequently: true }); x.drawImage(img, 0, 0);
  return x.getImageData(0, 0, c.width, c.height);
}

async function mapFor(key) {
  if (cache[key]) return cache[key];
  meta ??= await fetch(A + "flat.json").then((r) => r.json());
  const [base, ids] = await Promise.all([loadImg(`${A}${key}.png`), loadImg(`${A}${key}_ids.png`)]);
  const bd = pixels(base), id = pixels(ids);
  const n = base.width * base.height;
  const lum = new Float32Array(n), plate = new Uint8Array(n), tint = new Float32Array(n);
  let X0 = 1e9, Y0 = 1e9, X1 = 0, Y1 = 0;
  for (let i = 0; i < n; i++) {
    lum[i] = (bd.data[i * 4] + bd.data[i * 4 + 1] + bd.data[i * 4 + 2]) / 3; plate[i] = id.data[i * 4];
    tint[i] = (id.data[i * 4 + 1] / 255) * (bd.data[i * 4 + 3] / 255);
    if (bd.data[i * 4 + 3] > 0) { const x = i % base.width, y = (i / base.width) | 0; if (x < X0) X0 = x; if (x > X1) X1 = x; if (y < Y0) Y0 = y; if (y > Y1) Y1 = y; }
  }
  const plateGroup = new Array(256).fill(null);
  for (const p of meta.maps[key].plates) plateGroup[p.id] = p.group;
  const crop = { X0: Math.max(0, X0 - 12), Y0: Math.max(0, Y0 - 12), X1: Math.min(base.width - 1, X1 + 12), Y1: Math.min(base.height - 1, Y1 + 12) };
  return (cache[key] = { w: base.width, h: base.height, base: bd, lum, plate, tint, plateGroup, crop });
}

const hex = (h) => [1, 3, 5].map((k) => parseInt(h.slice(k, k + 2), 16));
// One hue: the design system's moss accent for primary, its accent line for secondary. The figure itself is light gray in both themes.
const P = hex("#456938"), SC = hex("#aec6a6");

async function renderOne(key, primary, secondary) {
  const ck = `${key}|${[...primary].sort().join(",")}|${[...secondary].sort().join(",")}`;
  if (rendered.has(ck)) return rendered.get(ck);
  const M = await mapFor(key);
  const { X0, Y0, X1, Y1 } = M.crop; const CW = X1 - X0 + 1, CH = Y1 - Y0 + 1;
  const c = document.createElement("canvas"); c.width = CW; c.height = CH;
  const ctx = c.getContext("2d");
  ctx.putImageData(M.base, -X0, -Y0, X0, Y0, CW, CH);
  const out = ctx.createImageData(M.w, M.h), d = out.data;
  const col = new Array(256).fill(null);
  for (let id = 1; id < 256; id++) { const g = M.plateGroup[id]; if (!g) continue; if (primary.includes(g)) col[id] = P; else if (secondary.includes(g)) col[id] = SC; }
  for (let i = 0, n = M.w * M.h; i < n; i++) {
    const c2 = col[M.plate[i]]; if (!c2) continue; const a = M.tint[i]; if (a <= 0) continue;
    const sh = Math.min(1.12, M.lum[i] / 182), k = i * 4;
    d[k] = Math.min(255, c2[0] * sh); d[k + 1] = Math.min(255, c2[1] * sh); d[k + 2] = Math.min(255, c2[2] * sh); d[k + 3] = Math.round(a * 235);
  }
  const over = document.createElement("canvas"); over.width = CW; over.height = CH;
  over.getContext("2d").putImageData(out, -X0, -Y0, X0, Y0, CW, CH);
  ctx.drawImage(over, 0, 0);
  rendered.set(ck, c);
  return c;
}

// Draws front + back into container. Each call clones cached canvases so one render can appear in several places.
export async function renderMuscles(container, { primary = [], secondary = [], sex = "male", compact = false } = {}) {
  container.innerHTML = `<div class="muted small center">Loading body map…</div>`;
  const canvases = [];
  for (const side of ["front", "back"]) {
    const src = await renderOne(`${sex}_${side}`, primary, secondary);
    const c = document.createElement("canvas"); c.width = src.width; c.height = src.height; c.getContext("2d").drawImage(src, 0, 0);
    canvases.push(c);
  }
  if (!container.isConnected) return;
  container.innerHTML = "";
  const wrap = document.createElement("div"); wrap.className = "body" + (compact ? " compact" : ""); wrap.append(...canvases); container.append(wrap);
}
