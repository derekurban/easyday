// Step-through form tutorial. Mounts into a container, driven by tutorial.json.
// Each step: a base frame, a highlighted marker with a tooltip, an optional close-up, an optional bar path.
const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

export function mountTutorial(root, data) {
  const src = (id) => `${data.dir}/${id}.png`;
  let i = 0;
  let closeup = false;
  let front = 0;

  root.innerHTML = `
    <div class="stage" id="tut-stage">
      <img id="tut-img0" alt=""><img id="tut-img1" class="out" alt="">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" id="tut-path"><path d=""/></svg>
      <div id="tut-marks"></div>
      <div class="tip" id="tut-tip"></div>
      <button class="btn ghost back" id="tut-back" hidden>Back to full view</button>
      <span class="cap" id="tut-cap"></span>
    </div>
    <div class="panel">
      <div class="count" id="tut-count"></div>
      <h3 id="tut-title"></h3>
      <p id="tut-text"></p>
      <button class="closeup" id="tut-closeup" hidden></button>
      <div class="ctrl"><button class="btn ghost" id="tut-prev">Back</button><button class="btn" id="tut-next">Next</button></div>
      <ol class="steps" id="tut-steps">${data.steps.map((s, k) => `<li data-k="${k}"><i>${k + 1}</i><span>${esc(s.title)}</span></li>`).join("")}</ol>
    </div>`;

  const $ = (id) => root.querySelector("#" + id);
  const imgs = [$("tut-img0"), $("tut-img1")];
  const showImage = (url, instant) => {
    const cur = imgs[front];
    if (cur.getAttribute("src") === url) return;
    const nxt = imgs[1 - front];
    nxt.src = url;
    const still = document.hidden || !document.hasFocus();
    const swap = () => { if (still) [cur, nxt].forEach((im) => (im.style.transition = "none")); nxt.classList.remove("out"); cur.classList.add("out"); front = 1 - front; if (still) setTimeout(() => [cur, nxt].forEach((im) => (im.style.transition = "")), 50); };
    if (instant || nxt.complete) swap(); else nxt.onload = swap;
  };

  const render = () => {
    const s = data.steps[i];
    const frame = data.frames[s.frame];
    const last = i === data.steps.length - 1;
    $("tut-count").textContent = `Step ${i + 1} of ${data.steps.length}`;
    $("tut-title").textContent = s.title;
    $("tut-text").textContent = s.tip;
    $("tut-prev").disabled = i === 0;
    $("tut-next").textContent = last ? "Start over" : "Next";
    root.querySelectorAll(".steps li").forEach((li, k) => { li.classList.toggle("on", k === i); li.classList.toggle("done", k < i); });

    const cu = $("tut-closeup");
    cu.hidden = !s.closeup;
    if (s.closeup) cu.innerHTML = `<img src="${src(s.closeup.id)}" alt=""><span><b>${closeup ? "Showing close-up" : "See the close-up"}</b>${esc(s.closeup.caption)}</span>`;
    cu.classList.toggle("on", closeup);

    if (closeup && s.closeup) {
      showImage(src(s.closeup.id));
      $("tut-marks").innerHTML = "";
      $("tut-tip").hidden = true;
      $("tut-path").hidden = true;
      $("tut-back").hidden = false;
      $("tut-cap").textContent = "Close-up";
      return;
    }
    showImage(src(frame.id));
    $("tut-back").hidden = true;
    $("tut-cap").textContent = frame.label;

    // markers: every step that lives on this frame, current one lit
    const marks = data.steps.map((st, k) => ({ st, k })).filter((o) => o.st.frame === s.frame);
    $("tut-marks").innerHTML = marks.map(({ st, k }) => {
      const pts = k === i && st.markers ? st.markers : [st.marker];
      return pts.map((m) => `<span class="mk ${k === i ? "on" : ""}" data-k="${k}" style="left:${m[0]}%;top:${m[1]}%">${k + 1}</span>`).join("");
    }).join("");

    const [x, y] = s.marker;
    const tip = $("tut-tip");
    tip.hidden = false;
    tip.innerHTML = `<b>${esc(s.title)}</b><span>${esc(s.tip)}</span>`;
    // sit the tip above the marker when the marker is low, below it when high; centred, clamped to the stage
    tip.style.left = `${Math.min(Math.max(x, 22), 78)}%`;
    tip.style.top = y > 50 ? "auto" : `calc(${y}% + 20px)`;
    tip.style.bottom = y > 50 ? `calc(${100 - y}% + 20px)` : "auto";
    tip.classList.toggle("below", y <= 50);
    // if the tip runs off the stage, flip it to the other side of the marker
    const st = $("tut-stage").getBoundingClientRect();
    const tr = tip.getBoundingClientRect();
    if (y > 50 && tr.top < st.top + 4) { tip.style.bottom = "auto"; tip.style.top = `calc(${y}% + 20px)`; tip.classList.add("below"); }
    else if (y <= 50 && tr.bottom > st.bottom - 4) { tip.style.top = "auto"; tip.style.bottom = `calc(${100 - y}% + 20px)`; tip.classList.remove("below"); }

    const path = $("tut-path");
    const showPath = s.path && data.path && data.path.frames.includes(s.frame);
    path.hidden = !showPath;
    if (showPath) path.querySelector("path").setAttribute("d", data.path.d);
  };

  const go = (k) => { i = (k + data.steps.length) % data.steps.length; closeup = false; render(); };
  $("tut-prev").onclick = () => go(i - 1);
  $("tut-next").onclick = () => go(i + 1);
  $("tut-back").onclick = () => { closeup = false; render(); };
  $("tut-closeup").onclick = () => { closeup = !closeup; render(); };
  $("tut-steps").onclick = (e) => { const li = e.target.closest("li"); if (li) go(+li.dataset.k); };
  $("tut-marks").onclick = (e) => { const m = e.target.closest(".mk"); if (m) go(+m.dataset.k); };
  root.tabIndex = 0;
  root.onkeydown = (e) => { if (e.key === "ArrowRight") go(i + 1); if (e.key === "ArrowLeft") go(i - 1); };
  // preload every image once so steps switch without a flash
  const all = new Set([...Object.values(data.frames).map((f) => f.id), ...data.steps.filter((s) => s.closeup).map((s) => s.closeup.id)]);
  for (const id of all) { const im = new Image(); im.src = src(id); }
  render();
  return { go };
}
