// Step-first exercise guide. One visual per step, a "do" line, and the things to remember.
// Driven by steps.json. Arrows (bar direction) are drawn by the app over the frame.
const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

export function mountSteps(root, data) {
  const src = (id) => `${data.dir}/${id}.png`;
  let i = 0;
  let front = 0;

  root.innerHTML = `
    <header class="exh">
      <div class="thumb"><img src="${src(data.thumbnail.id)}" alt=""></div>
      <div><h3>${esc(data.exercise)}</h3><p>${esc(data.summary)}</p><p class="count">${data.steps.length} steps</p></div>
    </header>
    <div class="stage" id="st-stage">
      <img id="st-img0" alt=""><img id="st-img1" class="out" alt="">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" id="st-arrow"><defs><marker id="st-head" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z"/></marker></defs><path class="line" d="" marker-end="url(#st-head)"/></svg>
      <span class="cap" id="st-cap"></span>
    </div>
    <div class="panel">
      <div class="count" id="st-count"></div>
      <h3 id="st-title"></h3>
      <p id="st-do"></p>
      <div class="remember"><div class="label">Things to remember</div><ul id="st-rem"></ul></div>
      <div class="ctrl"><button class="btn ghost" id="st-prev">Back</button><button class="btn" id="st-next">Next</button></div>
    </div>
    <ol class="strip" id="st-strip">${data.steps.map((s, k) => `<li data-k="${k}"><img src="${src(s.visual.id)}" alt="" loading="lazy"><span><i>${k + 1}</i>${esc(s.title)}</span></li>`).join("")}</ol>`;

  const $ = (id) => root.querySelector("#" + id);
  const imgs = [$("st-img0"), $("st-img1")];
  const showImage = (url) => {
    const cur = imgs[front];
    if (cur.getAttribute("src") === url) return;
    const nxt = imgs[1 - front];
    const still = document.hidden || !document.hasFocus();
    const swap = () => {
      if (still) [cur, nxt].forEach((im) => (im.style.transition = "none"));
      nxt.classList.remove("out"); cur.classList.add("out"); front = 1 - front;
      if (still) setTimeout(() => [cur, nxt].forEach((im) => (im.style.transition = "")), 50);
    };
    nxt.src = url;
    if (nxt.complete) swap(); else nxt.onload = swap;
  };

  const render = () => {
    const s = data.steps[i];
    const last = i === data.steps.length - 1;
    $("st-count").textContent = `Step ${i + 1} of ${data.steps.length}`;
    $("st-title").textContent = s.title;
    $("st-do").textContent = s.do;
    $("st-rem").innerHTML = s.remember.map((r) => `<li>${esc(r)}</li>`).join("");
    $("st-prev").disabled = i === 0;
    $("st-next").textContent = last ? "Start over" : "Next";
    $("st-cap").textContent = `${i + 1} · ${s.title}`;
    root.querySelectorAll(".strip li").forEach((li, k) => { li.classList.toggle("on", k === i); li.classList.toggle("done", k < i); });
    root.querySelector(".strip li.on")?.scrollIntoView({ block: "nearest", inline: "nearest" });
    showImage(src(s.visual.id));
    const arrow = $("st-arrow");
    arrow.hidden = !s.arrow;
    if (s.arrow) arrow.querySelector("path.line").setAttribute("d", s.arrow);
  };

  const go = (k) => { i = (k + data.steps.length) % data.steps.length; render(); };
  $("st-prev").onclick = () => go(i - 1);
  $("st-next").onclick = () => go(i + 1);
  $("st-strip").onclick = (e) => { const li = e.target.closest("li"); if (li) go(+li.dataset.k); };
  root.tabIndex = 0;
  root.onkeydown = (e) => { if (e.key === "ArrowRight") go(i + 1); if (e.key === "ArrowLeft") go(i - 1); };
  for (const s of data.steps) { const im = new Image(); im.src = src(s.visual.id); }
  render();
  return { go };
}
