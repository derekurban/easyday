// App controller: screens, events, timers. Logic lives in planner.js and loops.js.
import { S, save, reset, replace, now, daysBetween, fmtDate, monthKey, exportJSON } from "./store.js";
import { EQUIPMENT, EQUIPMENT_GROUPS, TEMPLATES, PATTERNS, GOALS, EXPERIENCE, EXERCISES, byId, ROUTINES, cardioFor, available } from "./library.js";
import { PARAMS, GROUPS, PACE, GUARDRAILS, params } from "./params.js";
import { SIZES, location, personState, STATE_LABEL, rangeFor, fmtLoad, fmtNum, unitLabel, stepFor, setTarget, warmups, alternatives, rebuildRotation, initPlan, currentItem, cycleView, defaultSize, buildSession, swapExercise, patternName, shufflePicks, sessionMuscles } from "./planner.js";
import { startSession, finishSession } from "./loops.js";
import { renderMuscles } from "./muscle-map.js";
import { mountArt } from "./art.js";

const $ = (s, r = document) => r.querySelector(s);
const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const ico = (name, cls = "") => `<i data-lucide="${name}" class="${cls}"></i>`;
const artEl = (name, cls = "") => `<span class="art ${cls}" data-art="${name}" aria-hidden="true"></span>`;
const app = $("#app"), nav = $("#nav"), sheetRoot = $("#sheet-root"), sheetEl = $("#sheet");

let view = { screen: "today" };
const ui = { size: null, locationId: null, swap: null, picks: {}, overrides: {}, ob: null, restStart: null, restHidden: false, restCued: false, timer: null, finish: null, chartTable: false, barSel: null, open: {}, exportOpen: false, showMap: true, segPos: {}, cat: { mode: "plan", q: "", pattern: "", muscle: "", here: true, category: "", equip: "", level: "", planOnly: false }, edit: null, lastTap: null, pausedAt: null, endCued: false };
let dataset = null;
let audio = null;

// ---------- migrations for data saved by earlier builds
(function migrate() {
  for (const l of S.locations) {
    if (l.equipment.some((t) => !EQUIPMENT[t])) { const t = TEMPLATES.find((x) => x.id === l.template); l.equipment = t ? t.equipment.slice() : l.equipment.filter((x) => EQUIPMENT[x]); }
  }
  if (S.profile && S.plan) rebuildRotation();
  save();
})();

// ---------- helpers
function go(screen, extra = {}) { view = { screen, ...extra }; closeSheet(); render(); }
function icons(root = document) { try { window.lucide?.createIcons({ root }); } catch { /* icons are decoration */ } }
function sheet(html) { sheetEl.innerHTML = `<div class="grabber"></div>${html}`; sheetRoot.hidden = false; icons(sheetEl); mountArt(sheetEl); const open = () => sheetRoot.classList.add("open"); if (noAnim()) open(); else requestAnimationFrame(() => requestAnimationFrame(open)); }
function closeSheet() { sheetRoot.classList.remove("open"); sheetRoot.hidden = true; sheetEl.innerHTML = ""; ui.edit = null; }
const noAnim = () => document.documentElement.classList.contains("no-anim");
function stopTimer() { if (ui.timer) { clearInterval(ui.timer); ui.timer = null; } }
async function getDataset() { dataset ??= await fetch("../data/exercises.json").then((r) => r.json()); return dataset; }
const SIZE_LABEL = { small: "Small", normal: "Normal", big: "Big" };
const SIZE_HINT = { small: "Main lifts only. About 15 minutes.", normal: "The plan as written.", big: "The plan plus a bonus block. Never heavier." };
const STATE_ICON = { active: "activity", at_risk: "alert-triangle", lapsed: "moon", comeback: "sunrise" };
function exLine(e) { const ex = byId[e.exId]; return `${e.sets.length} × ${e.target.reps}${ex.repLabel ? " " + ex.repLabel : ""} · ${fmtLoad(ex, e.target.load)}`; }
function ago(ts) { const d = daysBetween(ts, now()); return d === 0 ? "today" : d === 1 ? "yesterday" : `${d} days ago`; }
function locId() { return ui.locationId ?? S.lastLocationId ?? S.locations[0]?.id; }
function previewSession() { return buildSession({ size: ui.size ?? defaultSize(), locationId: locId(), swap: ui.swap, picks: ui.picks, overrides: ui.overrides }); }
function seg(id, options, value, act, extra = "") { return `<div class="seg" data-seg="${id}">${options.map((o) => `<button class="${o.value === value ? "on" : ""}" data-act="${act}" data-arg="${o.value}" ${extra}>${o.icon ? ico(o.icon) : ""}${esc(o.label)}</button>`).join("")}</div>`; }

// Segmented thumb slides by transform. Positions are remembered per control id so a re-render still animates, and only within the same control.
function thumbs() {
  document.querySelectorAll(".seg").forEach((el) => {
    const on = el.querySelector("button.on"); if (!on) return;
    const th = document.createElement("span"); th.className = "thumb"; el.prepend(th);
    const id = el.dataset.seg;
    const to = { w: on.offsetWidth, x: on.offsetLeft }, from = id && ui.segPos[id] ? ui.segPos[id] : to;
    th.style.width = from.w + "px"; th.style.transform = `translateX(${from.x}px)`;
    const place = () => { th.style.width = to.w + "px"; th.style.transform = `translateX(${to.x}px)`; };
    if (noAnim() || (from.x === to.x && from.w === to.w)) place(); else requestAnimationFrame(place);
    if (id) ui.segPos[id] = to;
  });
}

// Sound and vibration for timers. Audio needs a user gesture first; we create the context on the first tap.
function ensureAudio() { try { audio ??= new (window.AudioContext || window.webkitAudioContext)(); if (audio.state === "suspended") audio.resume(); } catch { audio = null; } }
function cue(kind = "done") {
  try { navigator.vibrate?.(kind === "tick" ? 40 : [120, 70, 120]); } catch { /* optional */ }
  if (!audio) return;
  const notes = kind === "tick" ? [660] : [523, 784];
  notes.forEach((f, i) => { const o = audio.createOscillator(), g = audio.createGain(); o.type = "sine"; o.frequency.value = f; g.gain.value = 0.0001; o.connect(g); g.connect(audio.destination); const t = audio.currentTime + i * 0.18; o.start(t); g.gain.exponentialRampToValueAtTime(0.2, t + 0.02); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.16); o.stop(t + 0.18); });
}

const MARK = `<span class="mark" aria-label="Fitness"><svg viewBox="10 10 80 80" fill="none" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"><path class="l" d="M28 18 L18 18 L18 82 L28 82"/><path class="l" d="M34 50 H66 M34 42 V58 M42 37 V63 M58 37 V63 M66 42 V58" stroke-width="5.5"/><path class="r" d="M72 18 L82 18 L82 82 L72 82"/></svg><span>Fitness</span></span>`;

// ---------- render
function render() {
  stopTimer();
  nav.hidden = !S.profile;
  for (const b of nav.querySelectorAll("button")) b.classList.toggle("on", b.dataset.arg === (view.screen === "session" || view.screen === "finish" ? "today" : view.screen));
  let html = "";
  if (!S.profile) html = onboarding();
  else if (view.screen === "today" || view.screen === "session") html = S.active ? session() : today();
  else if (view.screen === "finish") html = finish();
  else if (view.screen === "progress") html = progress();
  else if (view.screen === "exercises") html = catalog();
  else if (view.screen === "settings") html = settings();
  app.innerHTML = `<div class="screen">${html}</div>`;
  window.scrollTo(0, 0);
  icons();
  mountArt(app);
  afterRender();
}

// ---------- onboarding
const BEATS = [
  { art: "intro-one-decision", title: "One decision a day", text: "Open the app and there is one session waiting. Start it or not. No planning, no choosing weights, no spreadsheet." },
  { art: "intro-dose", title: "The dose adapts", text: "Reps climb first, then weight. A short set holds everything. Erring easy is on purpose: too little costs a bit of growth, too much costs weeks." },
  { art: "intro-cycle", title: "A short cycle, not a calendar", text: "Full-body days and movement days take turns. Whatever day it is, the next session is simply next. There is nothing to miss." },
  { art: "intro-comeback", title: "Coming back is designed in", text: "A few days away gets one gentle nudge. A week away makes the next session lighter and shorter, on purpose, and ramps you back." },
  { art: "intro-move", title: "A walk counts", text: "On the days lifting feels like too much, ten minutes of movement keeps the habit alive. That is a real session here." },
];
function onboarding() {
  ui.ob ??= { step: 0, beat: 0, goal: null, experience: null, daysPerWeek: 3, sex: "male", units: "kg", locs: TEMPLATES.map((t) => ({ template: t.id, name: t.name, on: t.id === "gym" })) };
  const o = ui.ob;
  const dots = (n, cur) => `<div class="dots">${Array.from({ length: n }, (_, i) => `<i class="${i === cur ? "on" : i < cur ? "done" : ""}"></i>`).join("")}</div>`;
  const steps = (cur) => `<div class="row between stepbar"><span class="muted small">Step ${cur} of 4</span>${dots(4, cur - 1)}</div>`;
  const opt = (act, arg, on, title, sub, art = null, body = "") => `<button class="opt ${on ? "on" : ""} ${art ? "with-art" : ""}" data-act="${act}" data-arg="${arg}">${art ? artEl(art, "opt-art") : ""}<span class="opt-body"><b>${esc(title)}</b><span>${esc(sub)}</span>${body}</span>${on ? ico("check", "opt-check") : ""}</button>`;
  if (o.step === 0) {
    const b = BEATS[o.beat];
    return `<div class="intro">${MARK}
      <div class="beat" key="${o.beat}">${artEl(b.art, "hero")}<h1>${esc(b.title)}</h1><p class="muted">${esc(b.text)}</p></div>
      ${dots(BEATS.length, o.beat)}
      <div class="row" style="margin-top:16px">${o.beat > 0 ? `<button class="btn ghost" data-act="ob-beat" data-arg="-1">${ico("arrow-left")} Back</button>` : `<button class="btn ghost" data-act="ob-skip">Skip</button>`}
      <button class="btn primary" data-act="${o.beat < BEATS.length - 1 ? "ob-beat" : "ob-next"}" data-arg="1">${o.beat < BEATS.length - 1 ? "Next " + ico("arrow-right") : "Set up " + ico("arrow-right")}</button></div></div>`;
  }
  if (o.step === 1) return `${steps(1)}<h1>What are you after?</h1><p class="muted">Each one changes the reps, the rest, and how many days are movement days. Change it any time without losing progress.</p>
    <div class="stack settle">${Object.entries(GOALS).map(([k, g]) => opt("ob-goal", k, o.goal === k, g.name, g.blurb, g.icon, o.goal === k ? `<ul class="explain">${g.explain.map((x) => `<li>${ico("check")}${esc(x)}</li>`).join("")}</ul>` : "")).join("")}</div>
    <p class="row" style="margin-top:16px"><button class="btn ghost" data-act="ob-back">${ico("arrow-left")} Back</button><button class="btn primary" data-act="ob-next" ${o.goal ? "" : "disabled"}>Next ${ico("arrow-right")}</button></p>`;
  if (o.step === 2) return `${steps(2)}<h1>How much have you lifted?</h1><p class="muted">Only used to pick safe starting weights. The app corrects quickly from your first sessions.</p>
    <div class="stack settle">${Object.entries(EXPERIENCE).map(([k, g]) => opt("ob-exp", k, o.experience === k, g.name, g.blurb)).join("")}</div>
    <p class="row" style="margin-top:16px"><button class="btn ghost" data-act="ob-back">${ico("arrow-left")} Back</button><button class="btn primary" data-act="ob-next" ${o.experience ? "" : "disabled"}>Next ${ico("arrow-right")}</button></p>`;
  if (o.step === 3) return `${steps(3)}<h1>A few details</h1>
    <h2>${ico("calendar")}Days a week, roughly</h2>${seg("ob-days", [2, 3, 4].map((d) => ({ value: d, label: d === 4 ? "4 or more" : String(d) })), o.daysPerWeek, "ob-days")}
    <p class="muted small">Sets how long the cycle is. Nothing is pinned to a weekday.</p>
    <h2>${ico("scale")}Weights in</h2>${seg("ob-units", [{ value: "kg", label: "Kilograms" }, { value: "lb", label: "Pounds" }], o.units, "ob-units")}
    <h2>${ico("person-standing")}Muscle map figure</h2>${seg("ob-sex", [{ value: "male", label: "Male" }, { value: "female", label: "Female" }], o.sex, "ob-sex")}
    <p class="muted small">Only used to draw which muscles a session works.</p>
    <p class="row" style="margin-top:16px"><button class="btn ghost" data-act="ob-back">${ico("arrow-left")} Back</button><button class="btn primary" data-act="ob-next">Next ${ico("arrow-right")}</button></p>`;
  return `${steps(4)}<h1>Where do you train?</h1><p class="muted">Pick every place that applies. Each one picks exercises from what is there. Fine-tune the equipment later in settings.</p>
    <div class="stack settle">${o.locs.map((l, i) => opt("ob-loc", i, l.on, l.name, TEMPLATES[i].equipment.length === Object.keys(EQUIPMENT).length ? "Everything" : TEMPLATES[i].equipment.map((e) => EQUIPMENT[e]).join(", ") || "Bodyweight only", TEMPLATES[i].icon)).join("")}</div>
    <p class="row" style="margin-top:16px"><button class="btn ghost" data-act="ob-back">${ico("arrow-left")} Back</button><button class="btn primary" data-act="ob-finish" ${o.locs.some((l) => l.on) ? "" : "disabled"}>${ico("play")} Build my first session</button></p>`;
}
function finishOnboarding() {
  const o = ui.ob;
  S.profile = { goal: o.goal, experience: o.experience, daysPerWeek: o.daysPerWeek, sex: o.sex, createdAt: now() };
  S.units = o.units;
  S.locations = o.locs.filter((l) => l.on).map((l, i) => ({ id: `loc${i}_${Date.now().toString(36)}`, name: l.name, template: l.template, equipment: TEMPLATES.find((t) => t.id === l.template).equipment.slice() }));
  S.lastLocationId = S.locations[0].id;
  initPlan(); save(); ui.ob = null; go("today");
}

// ---------- today
function today() {
  const ps = personState(); save();
  const p = params();
  const size = ui.size ?? defaultSize();
  const s = previewSession();
  const item = currentItem();
  const banners = [];
  if (!S.sessions.length) banners.push(`<div class="banner accent">${ico("sprout")} Your first session. Weights start light on purpose, and the app learns from every set you log.</div>`);
  if (ps.state === "lapsed") banners.push(`<div class="banner accent">${ico("sunrise")} Welcome back. Today is lighter and shorter by design. Three of these and you are back where you were.</div>`);
  if (ps.state === "comeback") banners.push(`<div class="banner info">${ico("sunrise")} Comeback ${(S.person.comeback?.done ?? 0) + 1} of ${p.comebackSessions}. Weights are still scaled.</div>`);
  if (ps.state === "at_risk") banners.push(`<div class="banner warn">${ico("alert-triangle")} It has been ${ps.daysSince} days. A small session or ten minutes of movement counts.</div>`);
  if (S.plan.offerNormalOnce && !ui.size) banners.push(`<div class="banner">${ico("arrow-up")} Defaulting to normal today: the last few small sessions were clean. Small is one tap away.</div>`);
  for (const [pat, pause] of Object.entries(S.plan.paused)) banners.push(`<div class="banner">${ico("pause")} ${patternName(pat)} is resting until ${fmtDate(pause.until)}. It comes back lighter.</div>`);

  let body, mapCard = "";
  if (s.type === "lift") {
    body = `<div class="list settle">${s.exercises.map((e, i) => `<div class="exline" data-act="ex-info" data-arg="${i}"><span><span class="t">${esc(byId[e.exId].name)}</span><br><span class="muted small">${patternName(e.pattern)}${e.scaled ? " · scaled" : ""}${e.edited ? " · edited" : ""}</span></span><span class="m">${exLine(e)} ${ico("chevron-right")}</span></div>`).join("")}
      ${s.bonus ? `<div class="exline"><span class="t">${ico("flame")} Bonus: ${s.bonus.minutes} min easy cardio</span><span class="m">optional</span></div>` : ""}</div>
      <div class="row" style="margin-top:12px"><button class="btn sm" data-act="shuffle">${ico("shuffle")} Shuffle</button>${Object.keys(ui.picks).length || Object.keys(ui.overrides).length ? `<button class="btn sm ghost" data-act="picks-clear">${ico("undo-2")} Usual picks</button>` : ""}</div>`;
    const m = sessionMuscles(s);
    mapCard = `<div class="card"><h2 class="row between" style="margin-top:0"><span>${ico("person-standing")}What today works</span><button class="btn sm ghost" data-act="map-toggle">${ui.showMap ? "Hide" : "Show"}</button></h2>
      ${ui.showMap ? `<div id="session-map" data-p="${m.primary.join(",")}" data-s="${m.secondary.join(",")}"></div><div class="legend"><span><i class="p"></i>${m.primary.map(esc).join(", ") || "nothing in particular"}</span><span><i class="s"></i>${m.secondary.map(esc).join(", ") || "none"}</span></div>` : ""}</div>`;
  } else {
    body = s.kind === "cardio"
      ? `<p>${s.minutes} minutes at a pace where you could talk.</p><p class="muted small">${cardioFor(location(locId())?.equipment ?? []).filter((c) => c.id !== "any").map((c) => c.name).join(", ")}, or anything that raises the pulse.</p>`
      : `<p>${ROUTINES[s.routine].moves.length} moves, ${ROUTINES[s.routine].seconds} seconds each. About ${Math.round(ROUTINES[s.routine].moves.length * ROUTINES[s.routine].seconds / 60)} minutes.</p>`;
  }
  const cyc = cycleView();
  return `<div class="row between"><span class="chip ${ps.state}">${ico(STATE_ICON[ps.state])} ${STATE_LABEL[ps.state]}</span><span class="muted small">${ps.last ? "Last session " + ago(ps.last.endedAt) : "No sessions yet"}</span></div>
    ${banners.join("")}
    ${S.locations.length > 1 ? `<div class="row" style="margin-top:8px">${ico("map-pin")}<select data-input="loc" class="grow">${S.locations.map((l) => `<option value="${l.id}" ${l.id === locId() ? "selected" : ""}>${esc(l.name)}</option>`).join("")}</select></div>` : ""}
    <div class="card"><div class="row between"><span class="muted small">${s.swapped ? "Swapped from " + esc(item.name) : "Next in your cycle"}</span>${s.type === "lift" && s.focus ? `<span class="muted small">${esc(s.focus)}</span>` : ""}</div><h3>${s.type === "lift" ? ico("dumbbell") : s.kind === "cardio" ? ico("footprints") : ico("stretch-horizontal")} ${esc(s.name)}</h3>${body}</div>
    ${seg("size", SIZES.map((z) => ({ value: z, label: SIZE_LABEL[z] })), size, "size")}
    <p class="muted small">${SIZE_HINT[size]}</p>
    <p><button class="btn primary big" data-act="start">${ico("play")} Start</button></p>
    <p><button class="btn ghost" data-act="swap-open">${ico("footprints")} ${s.type === "lift" ? "Not today. Something lighter" : "Pick a different kind of movement"}</button>${ui.swap ? `<button class="btn ghost sm" data-act="swap-clear">${ico("undo-2")} Back to the plan</button>` : ""}</p>
    <div class="card"><h2 style="margin-top:0">${ico("repeat")}Your cycle</h2><div class="cycle">${cyc.map((c) => `<span class="pill ${c.current ? "on" : ""}">${ico(c.icon)}${esc(c.name)}</span>`).join("")}</div><p class="muted small" style="margin:8px 0 0">${esc(cyc.find((c) => c.current)?.detail ?? "")} today. Next is always next, whatever the date.</p></div>
    ${mapCard}`;
}

function swapSheet() {
  const cardio = cardioFor(location(locId())?.equipment ?? []);
  const sel = ui.swap?.cardio ?? "walk";
  const size = ui.size ?? defaultSize();
  sheet(`<div class="row between"><h3>${ico("footprints")} Something lighter</h3><button class="btn sm ghost" data-act="sheet-close" aria-label="Close">${ico("x")}</button></div><p class="muted small">Movement keeps the habit alive. It all counts.</p>
    <h2>${ico("stretch-horizontal")}Mobility</h2><div class="stack">${Object.entries(ROUTINES).map(([k, r]) => `<button class="opt" data-act="swap" data-arg="mobility:${k}"><span class="opt-body"><b>${esc(r.name)}</b><span>${r.moves.length} moves · about ${Math.round(r.moves.length * r.seconds / 60)} minutes</span></span>${ico("chevron-right", "opt-check")}</button>`).join("")}</div>
    <h2>${ico("heart-pulse")}Easy cardio</h2><div class="equip" style="margin-bottom:12px">${cardio.map((c) => `<button class="${c.id === sel ? "on" : ""}" data-act="cardio-pick" data-arg="${c.id}">${esc(c.name)}</button>`).join("")}</div>
    ${seg("minutes", [{ value: "small", label: "10 min" }, { value: "normal", label: "20 min" }, { value: "big", label: "30 min" }], size, "cardio-minutes")}
    <p style="margin-top:12px"><button class="btn primary" data-act="swap" data-arg="cardio:${sel}">${ico("footprints")} Use this instead</button></p>`);
}

// ---------- session
function session() {
  const a = S.active;
  if (a.type === "move") return moveSession(a);
  const idx = a.exercises.findIndex((e) => e.sets.some((s) => s.outcome === null));
  if (idx < 0) {
    if (a.bonus && !a.bonusDone) return `<h1>${ico("flame")} Bonus</h1><div class="card"><h3>${a.bonus.minutes} minutes easy cardio</h3><p class="muted">Optional. You chose big today.</p></div>
      <p><button class="btn primary big" data-act="bonus-done">${ico("check")} Done</button></p><p><button class="btn ghost" data-act="bonus-skip">Skip it</button></p>`;
    ui.finish ??= {}; view.screen = "finish"; return finish();
  }
  const e = a.exercises[idx], ex = byId[e.exId];
  const cur = e.sets.findIndex((s) => s.outcome === null);
  const doneSets = a.exercises.flatMap((x) => x.sets).filter((s) => s.outcome !== null).length, totalSets = a.exercises.flatMap((x) => x.sets).length;
  const restOn = ui.restStart && !ui.restHidden;
  const anyLogged = doneSets > 0;
  const wu = e.role === "main" && cur === 0 ? warmups(ex, e.target.load) : [];
  return `<div class="row between"><span class="muted small">${esc(a.name)} · ${idx + 1} of ${a.exercises.length}</span><button class="btn sm" data-act="stop-open">${ico("square")} Stop</button></div>
    <div class="progressbar"><i style="width:${(100 * doneSets / totalSets).toFixed(0)}%"></i></div>
    <div class="card"><div class="muted small">${patternName(e.pattern)}${e.scaled ? " · comeback, scaled" : ""}${e.edited ? " · edited" : ""}</div>
      <h3 data-act="ex-info" data-arg="${idx}">${esc(ex.name)} ${ico("info")}</h3>
      <p class="how">${esc(ex.how)}</p>
      <div class="target">${e.target.reps} <small>${ex.repLabel ?? "reps"}</small></div>
      <div class="muted">${fmtLoad(ex, e.target.load)} · ${e.sets.length} sets · rest ${e.rest}s</div>
      ${wu.length ? `<p class="muted small">${ico("thermometer")} Warm up first: ${wu.map((w) => `${w.reps} × ${fmtNum(w.load)}`).join(", then ")} ${unitLabel()}. Not logged.</p>` : ""}
      <div class="sets">${e.sets.map((s, i) => `<span class="set ${s.outcome ?? (i === cur ? "cur" : "")} ${ui.lastTap && ui.lastTap.idx === idx && ui.lastTap.set === i ? "pop" : ""}">${s.outcome === "done" ? ico("check") : s.outcome === "short" ? ico("minus") : i + 1}</span>`).join("")}</div>
      <p><button class="btn primary big" data-act="set-done">${ico("check")} Done · ${e.target.reps} ${ex.repLabel ?? "reps"}</button></p>
      <p><button class="btn big" data-act="set-short">${ico("minus")} Short</button></p>
      <div class="row between"><span class="muted small">Done means you hit ${e.target.reps}. Short means fewer.</span>${anyLogged ? `<button class="btn sm ghost" data-act="undo">${ico("undo-2")} Undo</button>` : ""}</div></div>
    ${a.exercises.slice(idx + 1).length ? `<h2>${ico("list")}Up next</h2><div class="list">${a.exercises.slice(idx + 1).map((x, j) => `<div class="exline" data-act="ex-info" data-arg="${idx + 1 + j}"><span class="t">${esc(byId[x.exId].name)}</span><span class="m">${exLine(x)}</span></div>`).join("")}</div>` : ""}
    ${restOn ? `<div class="rest"><span>${ico("timer")} Rest <span id="rest-time">…</span></span><button data-act="rest-skip">Go</button></div>` : ""}`;
}

function tapSet(outcome) {
  const a = S.active;
  const idx = a.exercises.findIndex((e) => e.sets.some((s) => s.outcome === null));
  const e = a.exercises[idx];
  const si = e.sets.findIndex((s) => s.outcome === null);
  if (ui.restStart) e.rests.push(Math.round((Date.now() - ui.restStart) / 1000));
  e.sets[si].outcome = outcome;
  ui.lastTap = { idx, set: si };
  ui.restStart = Date.now(); ui.restHidden = false; ui.restCued = false;
  save(); render();
}
function undoSet() {
  const a = S.active;
  for (let i = a.exercises.length - 1; i >= 0; i--) {
    const e = a.exercises[i];
    for (let j = e.sets.length - 1; j >= 0; j--) if (e.sets[j].outcome !== null) { e.sets[j].outcome = null; e.rests.pop(); ui.restStart = null; ui.lastTap = null; save(); render(); return; }
  }
}

function stopSheet() {
  sheet(`<div class="row between"><h3>${ico("square")} Stop here?</h3><button class="btn sm ghost" data-act="sheet-close" aria-label="Close">${ico("x")}</button></div><p class="muted small">Sets you did still count. The reason decides what the app learns.</p><div class="stack">
    <button class="opt" data-act="stop" data-arg="energy">${ico("battery-low", "opt-ico")}<span class="opt-body"><b>Out of energy</b><span>The day was too big, not the weights. Sessions may get smaller.</span></span></button>
    <button class="opt" data-act="stop" data-arg="time">${ico("clock", "opt-ico")}<span class="opt-body"><b>Out of time</b><span>Nothing changes about the weights.</span></span></button>
    <button class="opt" data-act="stop" data-arg="pain">${ico("bandage", "opt-ico")}<span class="opt-body"><b>Something hurts</b><span>This movement pattern rests for a week and comes back lighter.</span></span></button>
    <button class="btn ghost" data-act="sheet-close">Keep going</button></div>`);
}

function moveSession(a) {
  const paused = !!ui.pausedAt;
  const pauseBtn = `<button class="btn sm" data-act="move-pause">${paused ? ico("play") + " Resume" : ico("pause") + " Pause"}</button>`;
  if (a.kind === "cardio") {
    a.realStart ??= Date.now(); save();
    return `<div class="row between"><span class="muted small">${ico("heart-pulse")} Move day</span><span class="row">${pauseBtn}<button class="btn sm" data-act="stop-open">${ico("square")} Stop</button></span></div>
      <div class="card center">${artEl("intro-move", "hero sm")}<h3>${a.minutes} minutes</h3><div class="timer ${paused ? "paused" : ""}" id="timer">${a.minutes}:00</div><p class="muted">Talking pace. Nothing to track.</p></div>
      <p><button class="btn primary big" data-act="move-done">${ico("check")} Done</button></p>`;
  }
  const r = ROUTINES[a.routine];
  a.moveIdx ??= 0; a.moveStart ??= Date.now(); save();
  if (a.moveIdx >= r.moves.length) return `<div class="card center">${artEl("done", "hero sm")}<h3>${esc(r.name)}</h3><p>All moves done.</p></div><p><button class="btn primary big" data-act="move-done">${ico("check")} Done</button></p>`;
  const mv = r.moves[a.moveIdx];
  return `<div class="row between"><span class="muted small">${ico("stretch-horizontal")} ${esc(r.name)} · ${a.moveIdx + 1} of ${r.moves.length}</span><span class="row">${pauseBtn}<button class="btn sm" data-act="stop-open">${ico("square")} Stop</button></span></div>
    <div class="progressbar"><i style="width:${(100 * a.moveIdx / r.moves.length).toFixed(0)}%"></i></div>
    <div class="card center"><h3>${esc(mv.n)}</h3><div class="timer ${paused ? "paused" : ""}" id="timer">${r.seconds}</div><p class="how">${esc(mv.how)}</p><p class="muted small">Next: ${esc(r.moves[a.moveIdx + 1]?.n ?? "done")}</p></div>
    <p><button class="btn primary big" data-act="move-next">Next ${ico("arrow-right")}</button></p>`;
}

// ---------- finish
function finish() {
  const a = S.active;
  ui.finish ??= {};
  if (ui.finish.lines) {
    const lineIcon = (l) => /up to|reps next time\.$|harder next time|offer|defaults to normal/.test(l) && !/held|down/.test(l) ? "arrow-up" : /held/.test(l) ? "minus" : /down to|Two short|lower the floor|paused|resting/.test(l) ? "arrow-down" : /counts|done\./.test(l) ? "check" : "info";
    return `<div class="center">${artEl("done", "hero")}</div><h1 class="center">Done.</h1><div class="card"><ul class="lines settle">${ui.finish.lines.map((l) => `<li>${ico(lineIcon(l))}<span>${esc(l)}</span></li>`).join("")}</ul></div><p><button class="btn primary big" data-act="finish-home">Back to today</button></p>`;
  }
  if (!a) return today();
  const isMove = a.type === "move";
  const mins = Math.max(1, Math.round((Date.now() - (a.realStart ?? a.startedAt ?? Date.now())) / 60000));
  const done = isMove ? 0 : a.exercises.flatMap((e) => e.sets).filter((s) => s.outcome === "done").length;
  const total = isMove ? 0 : a.exercises.flatMap((e) => e.sets).length;
  const labels = isMove ? { easy: "Easy", right: "About right", too_much: "Hard" } : { easy: "Easy", right: "About right", too_much: "Too much" };
  return `<h1>${a.stopReason ? "Stopped. That counts." : "Done."}</h1>
    <div class="tiles">${isMove ? `<div class="tile">${ico("timer")}<b>${a.kind === "cardio" ? a.minutes : mins}</b><span>minutes</span></div><div class="tile">${ico("footprints")}<b>1</b><span>session</span></div>` : `<div class="tile">${ico("check-circle")}<b>${done}</b><span>of ${total} sets</span></div><div class="tile">${ico("timer")}<b>${mins}</b><span>minutes</span></div><div class="tile">${ico("dumbbell")}<b>${a.exercises.filter((e) => e.sets.some((s) => s.outcome)).length}</b><span>exercises</span></div>`}</div>
    <h2>${ico("message-circle")}How was it?</h2><p class="muted small" style="margin-top:0">One tap, or skip. It only nudges what comes next.</p>
    <div class="stack">${Object.entries(labels).map(([k, v]) => `<button class="btn big" data-act="feel" data-arg="${k}">${v}</button>`).join("")}<button class="btn ghost" data-act="feel" data-arg="">Skip</button></div>`;
}
function doFinish(feel) {
  const a = S.active;
  const f = ui.finish ?? {};
  const lines = finishSession(a, { feel: feel || null, stopReason: f.stopReason ?? null, stopAtExercise: f.stopAtExercise ?? null });
  ui.finish = { lines }; ui.restStart = null; ui.size = null; ui.swap = null; ui.picks = {}; ui.overrides = {}; ui.pausedAt = null; ui.endCued = false;
  render();
}

// ---------- progress
function progress() {
  const months = []; const d = new Date(now()); d.setDate(1);
  for (let i = 5; i >= 0; i--) { const m = new Date(d.getFullYear(), d.getMonth() - i, 1); months.push({ key: monthKey(m.getTime()), label: m.toLocaleDateString(undefined, { month: "short" }), n: 0 }); }
  for (const s of S.sessions) { const m = months.find((x) => x.key === monthKey(s.endedAt)); if (m) m.n++; }
  const thisKey = monthKey(now());
  const thisMonth = S.sessions.filter((s) => monthKey(s.endedAt) === thisKey);
  const daysActive = new Set(thisMonth.map((s) => new Date(s.endedAt).toDateString())).size;
  const max = Math.max(1, ...months.map((m) => m.n)) * 1.1;
  const W = 320, H = 160, top = 20, bottom = 22, ch = H - top - bottom, gap = 6, bw = (W - gap * (months.length - 1)) / months.length;
  const hi = ui.barSel ?? months.length - 1;
  const bars = months.map((m, i) => {
    const h = ch * m.n / max, x = i * (bw + gap), y = top + ch - h, r = Math.min(3, h / 2);
    const isHi = i === hi;
    const path = h <= 0 ? "" : `M${x},${top + ch} V${y + r} a${r},${r} 0 0 1 ${r},-${r} H${x + bw - r} a${r},${r} 0 0 1 ${r},${r} V${top + ch} Z`;
    return `<g data-act="bar" data-arg="${i}"><rect x="${x - gap / 2}" y="0" width="${bw + gap}" height="${H}" fill="transparent"/><path class="bar grow ${isHi ? "hi" : ""}" style="animation-delay:${i * 40}ms" d="${path}"/>
      ${isHi ? `<text class="val hi" x="${x + bw / 2}" y="${y - 6}" text-anchor="middle">${m.n}</text>` : ""}<text x="${x + bw / 2}" y="${H - 4}" text-anchor="middle">${m.label}</text></g>`;
  }).join("");
  const chart = ui.chartTable
    ? `<table><tr><th>Month</th><th>Sessions</th></tr>${months.map((m) => `<tr><td>${m.label}</td><td>${m.n}</td></tr>`).join("")}</table>`
    : `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Sessions per month"><line class="mid" x1="0" x2="${W}" y1="${top + ch / 2}" y2="${top + ch / 2}"/>${bars}<line class="base" x1="0" x2="${W}" y1="${top + ch}" y2="${top + ch}"/></svg>`;

  const trends = Object.keys(PATTERNS).filter((p) => PATTERNS[p].main).map((pat) => {
    const exs = EXERCISES.filter((e) => e.pattern === pat && S.targets[e.id]?.appearances > 0).sort((a, b) => S.targets[b.id].appearances - S.targets[a.id].appearances);
    const ex = exs[0]; if (!ex) return null;
    const pts = S.sessions.filter((s) => s.type === "lift").flatMap((s) => s.exercises.filter((e) => e.exId === ex.id).map((e) => ex.unit === "bw" ? e.target.reps + 2 * e.target.load : e.target.load));
    if (!pts.length) return null;
    const cur = S.targets[ex.id];
    const first = pts[0], last = ex.unit === "bw" ? cur.reps + 2 * cur.load : cur.load;
    const mn = Math.min(...pts, last), mx = Math.max(...pts, last, mn + 1);
    const all = [...pts, last];
    const X = (i) => (i / Math.max(1, all.length - 1) * 92 + 2).toFixed(1), Y = (v) => (2 + 24 * (1 - (v - mn) / (mx - mn))).toFixed(1);
    const path = all.map((v, i) => `${i === 0 ? "M" : "L"}${X(i)} ${Y(v)}`).join(" ");
    const label = ex.unit === "bw" ? `${first} to ${last} reps` : `${fmtNum(first)} to ${fmtNum(last)} ${unitLabel()}${ex.each ? " each" : ""}`;
    return `<div class="exline"><span><span class="t">${patternName(pat)}</span><br><span class="muted small">${esc(ex.name)}</span></span><span class="row"><svg class="spark" viewBox="0 0 96 28"><path pathLength="1" d="${path}"/><circle cx="${X(all.length - 1)}" cy="${Y(last)}" r="2.5"/></svg><span class="m">${label}</span></span></div>`;
  }).filter(Boolean);

  const recent = S.sessions.slice(-8).reverse();
  const sparse = S.sessions.length < 3;
  return `<h1>Progress</h1>
    <div class="tiles settle"><div class="tile emphasis">${ico("calendar-check")}<b>${thisMonth.length}</b><span>sessions this month</span></div><div class="tile">${ico("flame")}<b>${daysActive}</b><span>days active this month</span></div><div class="tile">${ico("layers")}<b>${S.sessions.length}</b><span>sessions total</span></div></div>
    ${sparse ? `<div class="card center">${artEl("empty-progress", "hero sm")}<p class="muted">${S.sessions.length === 0 ? "Nothing yet. The first one is the hard one." : "A trend needs a few sessions. Keep going and this fills in."}</p></div>` : ""}
    <h2 class="row between"><span>${ico("bar-chart-3")}Sessions per month</span> <button class="btn sm" data-act="chart-toggle">${ui.chartTable ? ico("bar-chart-3") + " Chart" : ico("table") + " Table"}</button></h2>
    <div class="viz-root">${chart}</div>
    <h2>${ico("trending-up")}Load trend</h2><div class="card">${trends.length ? `<div class="list">${trends.join("")}</div>` : `<p class="muted">Shows up after your first lifting session.</p>`}</div>
    <h2>${ico("history")}Recent</h2><div class="card">${recent.length ? `<div class="list">${recent.map((s) => `<div><div class="exline"><span class="t">${esc(s.name)}</span><span class="m">${fmtDate(s.endedAt)} · ${s.type === "move" ? "movement" : SIZE_LABEL[s.size].toLowerCase()}${s.comeback ? " · comeback" : ""}</span></div><div class="muted small">${esc(s.changes?.[0] ?? "")}</div></div>`).join("")}</div>` : `<p class="muted">Nothing yet.</p>`}</div>`;
}

// ---------- exercise catalog: the full free-exercise-db (876) plus the 68 the planner uses
const MUSCLES = ["abdominals", "abductors", "adductors", "biceps", "calves", "chest", "forearms", "glutes", "hamstrings", "lats", "lower back", "middle back", "neck", "quadriceps", "shoulders", "traps", "triceps"];
const DS_CATEGORIES = { strength: "Strength", stretching: "Stretching", cardio: "Cardio", plyometrics: "Plyometrics", powerlifting: "Powerlifting", "olympic weightlifting": "Olympic lifts", strongman: "Strongman" };
const DS_EQUIP = ["body only", "barbell", "dumbbell", "kettlebells", "cable", "machine", "bands", "e-z curl bar", "medicine ball", "exercise ball", "foam roll", "other"];
const DS_LEVEL = { beginner: "Beginner", intermediate: "Intermediate", expert: "Expert" };
const MACHINE_TAGS = ["cable", "lat_pulldown", "row_machine", "chest_press_machine", "shoulder_press_machine", "leg_press", "hack_squat", "leg_extension", "leg_curl", "smith", "assisted_machine", "back_extension", "calf_machine"];
const DS_TO_TAG = { barbell: ["barbell"], dumbbell: ["dumbbell"], kettlebells: ["kettlebell"], cable: ["cable"], machine: MACHINE_TAGS, bands: ["band"], "e-z curl bar": ["ez_bar", "barbell"], "medicine ball": ["medicine_ball"], "exercise ball": ["exercise_ball"], "foam roll": ["foam_roller"] };
const byRef = Object.fromEntries(EXERCISES.map((e) => [e.ref, e]));
const IMG = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/";
function dsAvailable(d, equipment) {
  const tags = DS_TO_TAG[d.equipment]; if (!tags) return true;           // body only, other, unknown
  return tags.some((t) => equipment.includes(t));
}
function needsText(ex) { return ex.needs.map((set) => set.map((t) => EQUIPMENT[t]).join(" + ") || "nothing").join(" or "); }
function catalogItems() {
  const c = ui.cat, q = c.q.trim().toLowerCase();
  const equipment = location(locId())?.equipment ?? [];
  if (c.mode === "plan") {
    return EXERCISES.filter((ex) => (!c.pattern || ex.pattern === c.pattern) && (!c.muscle || ex.m.p.includes(c.muscle) || ex.m.s.includes(c.muscle)) && (!c.here || available(ex, equipment)) && (!q || ex.name.toLowerCase().includes(q) || ex.how.toLowerCase().includes(q)))
      .map((ex) => ({ id: ex.id, name: ex.name, sub: needsText(ex) + (ex.unit === "bw" ? " · bodyweight" : ""), group: patternName(ex.pattern), ok: available(ex, equipment), right: S.targets[ex.id] ? `${S.targets[ex.id].reps} × ${fmtLoad(ex, S.targets[ex.id].load)}` : "" }));
  }
  if (!dataset) return null;
  return dataset.filter((d) => (!c.category || d.category === c.category) && (!c.equip || d.equipment === c.equip) && (!c.level || d.level === c.level) && (!c.muscle || d.primaryMuscles.includes(c.muscle) || d.secondaryMuscles.includes(c.muscle)) && (!c.here || dsAvailable(d, equipment)) && (!c.planOnly || byRef[d.id]) && (!q || d.name.toLowerCase().includes(q)))
    .map((d) => ({ id: "ds:" + d.id, name: d.name, sub: [d.equipment ?? "no equipment", d.primaryMuscles.join(", ")].filter(Boolean).join(" · "), group: d.primaryMuscles[0] ?? "other", ok: dsAvailable(d, equipment), right: byRef[d.id] ? "in your plan" : (DS_LEVEL[d.level] ?? "") }))
    .sort((a, b) => a.group.localeCompare(b.group) || a.name.localeCompare(b.name));
}
function catalogList() {
  const items = catalogItems();
  if (items === null) return `<div class="card center"><p class="muted">Loading the full library…</p></div>`;
  if (!items.length) return `<div class="card center">${artEl("loc-none", "hero sm")}<p class="muted">Nothing matches. Loosen a filter, or turn off the location filter.</p></div>`;
  const groups = {};
  for (const it of items) (groups[it.group] ??= []).push(it);
  return Object.entries(groups).map(([g, list]) => `<h2>${ico(ui.cat.mode === "plan" ? "dumbbell" : "person-standing")}${esc(g)} <span class="muted" style="margin-left:6px">${list.length}</span></h2><div class="card"><div class="list">${list.map((it) => `<div class="exline ${it.ok ? "" : "dim"}" data-act="cat-info" data-arg="${it.id}"><span><span class="t">${esc(it.name)}</span><br><span class="muted small">${esc(it.sub)}</span></span><span class="m">${it.right === "in your plan" ? `<span class="chip active">${ico("check")} plan</span>` : esc(it.right)}${it.ok ? "" : ico("ban")} ${ico("chevron-right")}</span></div>`).join("")}</div></div>`).join("");
}
function catalogCount() { const items = catalogItems(); return items === null ? "Loading…" : `${items.length} of ${ui.cat.mode === "plan" ? EXERCISES.length : dataset.length}. Tap one for how to do it and what it works.`; }
function catalog() {
  const c = ui.cat;
  const loc = location(locId());
  if (c.mode !== "plan" && !dataset) getDataset().then(() => { if (view.screen === "exercises") render(); });
  const sel = (key, opts, cur, blank) => `<select data-input="${key}" class="grow"><option value="">${blank}</option>${opts.map(([v, l]) => `<option value="${v}" ${cur === v ? "selected" : ""}>${esc(l)}</option>`).join("")}</select>`;
  return `<h1>Exercises</h1>
    ${seg("cat-mode", [{ value: "plan", label: `In your plan · ${EXERCISES.length}` }, { value: "all", label: `Everything · ${dataset ? dataset.length : "876"}` }], c.mode, "cat-mode")}
    <p class="muted small" id="cat-count" style="margin:8px 0">${catalogCount()}</p>
    <div class="row">${ico("search")}<input type="text" class="grow" placeholder="Search" value="${esc(c.q)}" data-input="cat-q" autocomplete="off"></div>
    ${c.mode === "plan"
      ? `<div class="equip" style="margin:10px 0"><button class="${!c.pattern ? "on" : ""}" data-act="cat-pattern" data-arg="">All</button>${Object.entries(PATTERNS).map(([k, p]) => `<button class="${c.pattern === k ? "on" : ""}" data-act="cat-pattern" data-arg="${k}">${esc(p.name)}</button>`).join("")}</div>`
      : `<div class="equip" style="margin:10px 0"><button class="${!c.category ? "on" : ""}" data-act="cat-category" data-arg="">All</button>${Object.entries(DS_CATEGORIES).map(([k, l]) => `<button class="${c.category === k ? "on" : ""}" data-act="cat-category" data-arg="${k}">${l}</button>`).join("")}</div>
         <div class="row" style="margin-bottom:8px">${sel("cat-equip", DS_EQUIP.map((e) => [e, e]), c.equip, "Any equipment")}${sel("cat-level", Object.entries(DS_LEVEL), c.level, "Any level")}</div>`}
    <div class="row" style="margin-bottom:8px">${sel("cat-muscle", MUSCLES.map((m) => [m, m]), c.muscle, "Any muscle")}
      <label class="row small" style="white-space:nowrap"><input type="checkbox" data-input="cat-here" ${c.here ? "checked" : ""}> ${ico("map-pin")}</label>${S.locations.length > 1 ? `<select data-input="cat-loc" style="max-width:40%">${S.locations.map((l) => `<option value="${l.id}" ${l.id === loc?.id ? "selected" : ""}>${esc(l.name)}</option>`).join("")}</select>` : `<span class="small muted">${esc(loc?.name ?? "")}</span>`}</div>
    ${c.mode === "all" ? `<label class="row small" style="margin-bottom:8px"><input type="checkbox" data-input="cat-plan" ${c.planOnly ? "checked" : ""}> Only exercises the planner uses</label>` : ""}
    <div id="cat-list">${catalogList()}</div>`;
}
function refreshCatalog() {
  const el = $("#cat-list"); if (!el) return;
  el.innerHTML = catalogList(); icons(el); mountArt(el);
  const n = $("#cat-count"); if (n) n.textContent = catalogCount();
}
async function catalogInfo(id) {
  const loc = location(locId());
  const equipment = loc?.equipment ?? [];
  if (id.startsWith("ds:")) {
    const ds = await getDataset();
    const d = ds.find((x) => x.id === id.slice(3)); if (!d) return;
    const ex = byRef[d.id];
    const ok = dsAvailable(d, equipment);
    sheet(`<div class="row between"><h3>${esc(d.name)}</h3><button class="btn sm ghost" data-act="sheet-close" aria-label="Close">${ico("x")}</button></div>
      <p class="muted small">${[DS_CATEGORIES[d.category] ?? d.category, d.equipment ?? "no equipment", d.mechanic, d.force, DS_LEVEL[d.level]].filter(Boolean).map(esc).join(" · ")}</p>
      ${ok ? "" : `<div class="banner">${ico("ban")} Probably not available at ${esc(loc?.name ?? "this location")}.</div>`}
      ${ex ? `<div class="banner accent">${ico("check")} In your plan as "${esc(ex.name)}" (${patternName(ex.pattern)}). <a href="#" data-act="cat-info" data-arg="${ex.id}">Open it</a>.</div>` : ""}
      <div class="photos"><img src="${IMG}${d.images[0] ?? ""}" alt="" loading="lazy" onerror="this.remove()"><img src="${IMG}${d.images[1] ?? ""}" alt="" loading="lazy" onerror="this.remove()"></div>
      <div id="muscles"></div>
      <p class="small muted">${ico("person-standing")} ${d.primaryMuscles.map(esc).join(", ") || "not specified"}${d.secondaryMuscles.length ? ` · also ${d.secondaryMuscles.map(esc).join(", ")}` : ""}</p>
      <ol class="instr">${d.instructions.map((x) => `<li>${esc(x)}</li>`).join("") || `<li class="muted">No instructions in the dataset.</li>`}</ol>
      <p class="muted small">Source: free-exercise-db, public domain.</p>`);
    renderMuscles($("#muscles"), { primary: d.primaryMuscles, secondary: d.secondaryMuscles, sex: S.profile.sex }).catch(() => { if ($("#muscles")) $("#muscles").innerHTML = ""; });
    return;
  }
  const ex = byId[id]; if (!ex) return;
  const t = S.targets[ex.id];
  const ok = available(ex, equipment);
  const role = PATTERNS[ex.pattern].main ? "main" : "acc";
  const range = rangeFor(ex, role, t ?? { load: 0 });
  const used = S.sessions.filter((s) => s.type === "lift" && s.exercises.some((e) => e.exId === ex.id)).length;
  const start = ex.unit === "bw" ? `bodyweight, ${ex.range[0]} reps` : fmtLoad(ex, ex.start[S.profile.experience]);
  sheet(`<div class="row between"><h3>${esc(ex.name)}</h3><button class="btn sm ghost" data-act="sheet-close" aria-label="Close">${ico("x")}</button></div>
    <p class="muted small">${patternName(ex.pattern)} · ${role === "main" ? "main lift" : "accessory"} · ${range[0]} to ${range[1]} ${ex.repLabel ?? "reps"} · needs ${esc(needsText(ex))}</p>
    ${ok ? "" : `<div class="banner">${ico("ban")} Not available at ${esc(loc?.name ?? "this location")}. Add the equipment in settings and it will be offered.</div>`}
    <p class="how">${esc(ex.how)}</p>
    <div class="card flat"><div class="row between"><span class="muted small">${ico("target")} Your target</span><span class="muted small">${used ? `in ${used} session${used === 1 ? "" : "s"}` : "not done yet"}</span></div>
      <p style="margin:6px 0 0">${t ? `<b>${t.reps} ${ex.repLabel ?? "reps"}</b> at <b>${fmtLoad(ex, t.load)}</b>${t.topHits ? ` · ${t.topHits} at the top of the range` : ""}` : `Would start at ${start} for your experience level.`}</p></div>
    <div class="photos" id="photos"></div>
    <div id="muscles"></div>
    <p class="small muted">${ico("person-standing")} ${ex.m.p.map(esc).join(", ")}${ex.m.s.length ? ` · also ${ex.m.s.map(esc).join(", ")}` : ""}</p>
    <details><summary>${ico("list-ordered")} Step by step${ico("chevron-down", "chev")}</summary><ol class="instr" id="instr"><li class="muted">Loading…</li></ol></details>`);
  renderMuscles($("#muscles"), { primary: ex.m.p, secondary: ex.m.s, sex: S.profile.sex }).catch(() => { if ($("#muscles")) $("#muscles").innerHTML = ""; });
  try {
    const ds = await getDataset();
    const ref = ds.find((d) => d.id === ex.ref);
    if ($("#instr")) $("#instr").innerHTML = ref ? ref.instructions.map((x) => `<li>${esc(x)}</li>`).join("") : `<li class="muted">${esc(ex.how)}</li>`;
    if ($("#photos") && ref?.images?.length) $("#photos").innerHTML = ref.images.slice(0, 2).map((p) => `<img src="${IMG}${p}" alt="" loading="lazy" onerror="this.remove()">`).join("");
  } catch { if ($("#instr")) $("#instr").innerHTML = `<li class="muted">${esc(ex.how)}</li>`; }
}

// ---------- settings
function settings() {
  const p = params();
  const simDate = new Date(now()).toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" });
  const equipChips = (l) => EQUIPMENT_GROUPS.map((g) => `<div class="egroup">${g.name}</div><div class="equip">${Object.entries(g.items).map(([k, v]) => `<button class="${l.equipment.includes(k) ? "on" : ""}" data-act="loc-equip" data-arg="${l.id}:${k}">${v}</button>`).join("")}</div>`).join("");
  const g = GOALS[S.profile.goal];
  const details = (key, title, icon, body) => `<details ${ui.open[key] ? "open" : ""} data-open-key="${key}"><summary>${ico(icon)} ${title}${ico("chevron-down", "chev")}</summary>${body}</details>`;
  const cyc = cycleView();
  return `<h1>Settings</h1>
    <h2>${ico("target")}Goal</h2>
    <div class="stack">${Object.entries(GOALS).map(([k, x]) => `<button class="opt with-art ${S.profile.goal === k ? "on" : ""}" data-act="goal-set" data-arg="${k}">${artEl(x.icon, "opt-art")}<span class="opt-body"><b>${esc(x.name)}</b><span>${esc(x.blurb)}</span>${S.profile.goal === k ? `<ul class="explain">${x.explain.map((e) => `<li>${ico("check")}${esc(e)}</li>`).join("")}</ul>` : ""}</span>${S.profile.goal === k ? ico("check", "opt-check") : ""}</button>`).join("")}</div>
    <p class="muted small">Changing it keeps every weight. Reps restart at the bottom of the new range.</p>
    <h2>${ico("repeat")}Your cycle</h2><div class="card"><div class="cycle">${cyc.map((c) => `<span class="pill ${c.current ? "on" : ""}">${ico(c.icon)}${esc(c.name)}</span>`).join("")}</div>
      <div class="list" style="margin-top:8px">${cyc.map((c) => `<div class="exline"><span class="t">${esc(c.name)}</span><span class="m">${esc(c.detail)}</span></div>`).join("")}</div>
      <p class="muted small">${ico("info")} Built from your goal and ${S.profile.daysPerWeek === 4 ? "4 or more" : S.profile.daysPerWeek} days a week. Baseline size ${S.plan.baselineSize}${S.plan.extraAccessories ? `, plus ${S.plan.extraAccessories} accessory` : ""}${S.plan.floorLowered ? ", floor lowered" : ""}.</p>
      <div class="row">${ico("calendar")}${seg("days", [2, 3, 4].map((d) => ({ value: d, label: d === 4 ? "4 or more" : String(d) + " days" })), S.profile.daysPerWeek, "days-set")}</div></div>
    <h2>${ico("scale")}Weights in</h2>${seg("units", [{ value: "kg", label: "Kilograms" }, { value: "lb", label: "Pounds" }], S.units, "units")}
    <h2>${ico("gauge")}Pace</h2>${seg("pace", Object.entries(PACE).map(([k, v]) => ({ value: k, label: v.name })), S.pace, "pace")}
    <p class="muted small">${esc(PACE[S.pace].blurb)}</p>
    ${details("how", "How the app adjusts", "sliders-horizontal", GROUPS.map((grp) => `<div class="group"><h3>${ico(grp.icon)} ${esc(grp.title)}</h3><p class="muted small">${esc(grp.blurb)}</p>
      ${PARAMS.filter((x) => x.loop === grp.loop).map((x) => `<div class="param"><label>${esc(x.name)}<br><span class="u">${x.min} to ${x.max} ${x.unit}${x.off ? " · or off" : ""}</span></label><span class="row">${x.off ? `<label class="small row"><input type="checkbox" data-input="param-off" data-key="${x.key}" ${p[x.key] === null ? "checked" : ""}> off</label>` : ""}<input type="number" data-input="param" data-key="${x.key}" value="${p[x.key] ?? ""}" min="${x.min}" max="${x.max}" step="${x.step}" ${p[x.key] === null ? "disabled" : ""}></span></div>`).join("")}</div>`).join("") +
      `<p><button class="btn sm" data-act="params-reset">${ico("undo-2")} Back to the pace defaults</button></p>`)}
    ${details("guard", "What never changes", "shield", `<ul class="lines small">${GUARDRAILS.map((x) => `<li>${ico("lock")}<span>${esc(x)}</span></li>`).join("")}</ul>`)}
    <h2>${ico("map-pin")}Locations</h2>
    ${S.locations.map((l) => `<div class="card"><div class="row"><input type="text" class="grow" value="${esc(l.name)}" data-input="loc-name" data-id="${l.id}">${S.locations.length > 1 ? `<button class="btn sm danger" data-act="loc-del" data-arg="${l.id}" aria-label="Remove">${ico("trash-2")}</button>` : ""}</div>
      <div class="row" style="margin-top:8px"><button class="btn sm ghost" data-act="loc-all" data-arg="${l.id}:on">Everything</button><button class="btn sm ghost" data-act="loc-all" data-arg="${l.id}:off">Nothing</button><span class="muted small">${l.equipment.length} of ${Object.keys(EQUIPMENT).length}</span></div>
      ${details("eq_" + l.id, "Equipment", "wrench", equipChips(l))}</div>`).join("")}
    <div class="row">${ico("plus")}<select data-input="loc-add" class="grow"><option value="">Add a location…</option>${TEMPLATES.map((t) => `<option value="${t.id}">${t.name}</option>`).join("")}</select></div>
    ${Object.keys(S.plan.paused).length ? `<h2>${ico("pause")}Resting patterns</h2>${Object.entries(S.plan.paused).map(([k, v]) => `<div class="row between"><span>${patternName(k)} until ${fmtDate(v.until)}</span><button class="btn sm" data-act="pause-resume" data-arg="${k}">Bring it back now</button></div>`).join("")}` : ""}
    <h2>${ico("person-standing")}Muscle map figure</h2>${seg("sex", [{ value: "male", label: "Male" }, { value: "female", label: "Female" }], S.profile.sex, "sex")}
    <h2>${ico("info")}About</h2>
    <div class="card flat"><div class="row between"><span>${ico("wrench")} Developer tools</span><label class="switch"><input type="checkbox" data-input="dev" ${S.dev ? "checked" : ""}><i></i></label></div>
      ${S.dev ? `<hr style="margin:12px 0"><p class="small">Simulated date: <b>${simDate}</b>${S.clockOffsetDays ? ` (${S.clockOffsetDays > 0 ? "+" : ""}${S.clockOffsetDays} days)` : ""}</p>
      <div class="row"><button class="btn sm" data-act="clock" data-arg="1">+1 day</button><button class="btn sm" data-act="clock" data-arg="3">+3 days</button><button class="btn sm" data-act="clock" data-arg="7">+7 days</button><button class="btn sm ghost" data-act="clock" data-arg="0">Real time</button></div>
      <p class="small" style="margin-top:12px">Simulate clean sessions, two days apart, every set done.</p>
      <div class="row"><button class="btn sm" data-act="sim" data-arg="1">1 session</button><button class="btn sm" data-act="sim" data-arg="6">6 sessions</button><button class="btn sm" data-act="sim" data-arg="20">20 sessions</button></div>
      <p style="margin-top:12px" class="row"><button class="btn sm" data-act="export">${ico("database")} ${ui.exportOpen ? "Hide data" : "Show data"}</button> <button class="btn sm danger" data-act="reset">${ico("trash-2")} Reset everything</button></p>
      ${ui.exportOpen ? `<textarea data-input="import">${esc(exportJSON())}</textarea><p><button class="btn sm" data-act="import">Load the text above</button></p>` : ""}
      <p class="muted small">Logic spec: <a href="../docs/app-logic/">diagrams</a>.</p>` : `<p class="muted small" style="margin:8px 0 0">Prototype. Everything lives on this device.</p>`}</div>`;
}

function simulate(n) {
  const id = locId();
  for (let i = 0; i < n; i++) {
    if (S.sessions.length) S.clockOffsetDays += 2;
    const s = buildSession({ size: defaultSize(), locationId: id });
    s.defaultSize = defaultSize();
    startSession(s);
    if (s.type === "lift") for (const e of s.exercises) { for (const set of e.sets) set.outcome = "done"; e.rests = e.sets.slice(1).map(() => e.rest); }
    finishSession(s, { feel: "right" });
  }
  save();
}

// ---------- exercise info sheet, with today's target editor
async function exInfo(idx) {
  const inActive = !!S.active && S.active.type === "lift";
  const src = inActive ? S.active : previewSession();
  const e = src.exercises[idx]; if (!e) return;
  const ex = byId[e.exId];
  const t = S.targets[ex.id];
  const loc = location(inActive ? S.active.locationId : locId());
  const alts = alternatives(e.pattern, loc?.equipment ?? [], ex.id);
  ui.edit = { idx, slot: e.slot, exId: ex.id, load: e.target.load, reps: e.target.reps, inActive };
  const wu = e.role === "main" ? warmups(ex, e.target.load) : [];
  const times = t?.appearances ? `${t.appearances} time${t.appearances === 1 ? "" : "s"} so far` : "first time";
  sheet(`<div class="row between"><h3>${esc(ex.name)}</h3><button class="btn sm ghost" data-act="sheet-close" aria-label="Close">${ico("x")}</button></div>
    <p class="muted small">${patternName(e.pattern)} · ${e.role === "main" ? "main lift" : "accessory"} · ${e.range[0]} to ${e.range[1]} ${ex.repLabel ?? "reps"} · ${times}${t?.topHits ? ` · ${t.topHits} at the top` : ""}</p>
    <p class="how">${esc(ex.how)}</p>
    <div class="card flat"><div class="row between"><span class="muted small">${ico("pencil")} ${inActive ? "Today's target" : "Target for today"}</span>${e.edited ? `<span class="chip">edited</span>` : ""}</div>
      <div class="stepper"><span>${ex.repLabel ?? "Reps"}</span><button class="btn sm" data-act="edit" data-arg="reps:-1" aria-label="Fewer reps">${ico("minus")}</button><b id="edit-reps">${e.target.reps}</b><button class="btn sm" data-act="edit" data-arg="reps:1" aria-label="More reps">${ico("plus")}</button></div>
      ${ex.unit === "kg" ? `<div class="stepper"><span>Weight</span><button class="btn sm" data-act="edit" data-arg="load:-1" aria-label="Lighter">${ico("minus")}</button><b id="edit-load">${fmtNum(e.target.load)} <small>${unitLabel()}${ex.each ? " each" : ""}</small></b><button class="btn sm" data-act="edit" data-arg="load:1" aria-label="Heavier">${ico("plus")}</button></div>` : `<p class="muted small">Bodyweight. Harder versions come as the reps climb.</p>`}
      <div class="row" style="margin-top:8px"><button class="btn sm" data-act="edit-apply" data-arg="today">${ico("check")} Use today</button><button class="btn sm ghost" data-act="edit-apply" data-arg="save">${ico("save")} Save as my target</button></div>
      ${wu.length ? `<p class="muted small" style="margin:10px 0 0">${ico("thermometer")} Warm up: ${wu.map((w) => `${w.reps} × ${fmtNum(w.load)}`).join(", then ")} ${unitLabel()}.</p>` : ""}</div>
    <div id="muscles"></div>
    <p class="small muted">${ico("person-standing")} ${ex.m.p.map(esc).join(", ")}${ex.m.s.length ? ` · also ${ex.m.s.map(esc).join(", ")}` : ""}</p>
    <details><summary>${ico("list-ordered")} Step by step${ico("chevron-down", "chev")}</summary><ol class="instr" id="instr"><li class="muted">Loading…</li></ol></details>
    ${alts.length ? `<h2>${ico("repeat")}${inActive ? "Swap for today" : "Use instead"}</h2><div class="stack">${alts.map((a) => `<button class="opt" data-act="${inActive ? "ex-swap" : "ex-pick"}" data-arg="${inActive ? idx : e.slot}:${a.id}"><span class="opt-body"><b>${esc(a.name)}</b><span>${S.targets[a.id] ? "you have history with this" : "no history yet, starts conservative"}</span></span>${ico("chevron-right", "opt-check")}</button>`).join("")}</div>` : ""}`);
  renderMuscles($("#muscles"), { primary: ex.m.p, secondary: ex.m.s, sex: S.profile.sex }).catch(() => { if ($("#muscles")) $("#muscles").innerHTML = ""; });
  try {
    const ds = await getDataset();
    const ref = ds.find((d) => d.id === ex.ref);
    if ($("#instr")) $("#instr").innerHTML = ref ? ref.instructions.map((s) => `<li>${esc(s)}</li>`).join("") : `<li class="muted">${esc(ex.how)}</li>`;
  } catch { if ($("#instr")) $("#instr").innerHTML = `<li class="muted">${esc(ex.how)}</li>`; }
}
function editStep(what, dir) {
  const ed = ui.edit; if (!ed) return;
  const ex = byId[ed.exId];
  if (what === "reps") ed.reps = Math.max(1, ed.reps + dir);
  else ed.load = Math.max(0, Math.round((ed.load + dir * stepFor(ex)) * 1000) / 1000);
  const r = $("#edit-reps"), l = $("#edit-load");
  if (r) r.textContent = ed.reps;
  if (l) l.innerHTML = `${fmtNum(ed.load)} <small>${unitLabel()}${ex.each ? " each" : ""}</small>`;
}
function editApply(mode) {
  const ed = ui.edit; if (!ed) return;
  if (mode === "save") setTarget(ed.exId, { load: ed.load, reps: ed.reps });
  if (ed.inActive) {
    const e = S.active.exercises[ed.idx];
    e.target = { load: ed.load, reps: ed.reps }; e.edited = true;
  } else {
    ui.overrides[ed.slot] = { load: ed.load, reps: ed.reps };
  }
  save(); closeSheet(); render();
}

// ---------- after render: thumbs, body map, timers
function afterRender() {
  thumbs();
  const a = S.active;
  const map = $("#session-map");
  if (map) renderMuscles(map, { primary: map.dataset.p.split(",").filter(Boolean), secondary: map.dataset.s.split(",").filter(Boolean), sex: S.profile.sex, compact: true }).catch(() => { map.innerHTML = ""; });
  if (view.screen !== "finish" && a?.type === "lift" && ui.restStart && !ui.restHidden && $("#rest-time")) {
    const idx = a.exercises.findIndex((e) => e.sets.some((s) => s.outcome === null));
    const rest = a.exercises[idx]?.rest ?? 60;
    const tick = () => { const left = rest - Math.round((Date.now() - ui.restStart) / 1000); const el = $("#rest-time"); if (!el) return; el.textContent = left > 0 ? `${left}s` : "go"; if (left <= 0 && !ui.restCued) { ui.restCued = true; cue("done"); el.closest(".rest")?.classList.add("due"); } };
    tick(); ui.timer = setInterval(tick, 500);
  }
  if (a?.type === "move" && $("#timer")) {
    const elapsed = () => (ui.pausedAt ? ui.pausedAt : Date.now());
    if (a.kind === "cardio") {
      const tick = () => { const left = a.minutes * 60 - Math.round((elapsed() - a.realStart) / 1000); const el = $("#timer"); if (!el) return; const v = Math.max(0, left); el.textContent = `${Math.floor(v / 60)}:${String(v % 60).padStart(2, "0")}`; if (left <= 0 && !ui.endCued) { ui.endCued = true; cue("done"); el.classList.add("due"); } };
      tick(); ui.timer = setInterval(tick, 500);
    } else {
      const r = ROUTINES[a.routine];
      const tick = () => { const left = r.seconds - Math.round((elapsed() - a.moveStart) / 1000); const el = $("#timer"); if (!el) return; if (left <= 0 && !ui.pausedAt) { a.moveIdx++; a.moveStart = Date.now(); save(); cue("tick"); render(); return; } el.textContent = Math.max(0, left); };
      tick(); ui.timer = setInterval(tick, 250);
    }
  }
}

// ---------- events
document.addEventListener("click", (ev) => {
  const el = ev.target.closest("[data-act]"); if (!el) return;
  ensureAudio();
  const act = el.dataset.act, arg = el.dataset.arg;
  const o = ui.ob;
  const actions = {
    "nav": () => { ui.finish = null; go(arg); },
    "sheet-close": closeSheet,
    "ob-beat": () => { o.beat = Math.max(0, Math.min(BEATS.length - 1, o.beat + Number(arg))); render(); },
    "ob-skip": () => { o.step = 1; render(); },
    "ob-goal": () => { o.goal = arg; render(); }, "ob-exp": () => { o.experience = arg; render(); },
    "ob-days": () => { o.daysPerWeek = Number(arg); render(); }, "ob-sex": () => { o.sex = arg; render(); }, "ob-units": () => { o.units = arg; render(); },
    "ob-loc": () => { o.locs[Number(arg)].on = !o.locs[Number(arg)].on; render(); },
    "ob-next": () => { o.step++; render(); }, "ob-back": () => { if (o.step === 1) { o.step = 0; o.beat = BEATS.length - 1; } else o.step--; render(); }, "ob-finish": finishOnboarding,
    "size": () => { ui.size = arg; render(); },
    "shuffle": () => { const s = previewSession(); if (s.type === "lift") { ui.picks = shufflePicks(s, location(locId())?.equipment ?? []); ui.overrides = {}; } render(); },
    "picks-clear": () => { ui.picks = {}; ui.overrides = {}; render(); },
    "ex-pick": () => { const [slot, id] = arg.split(":"); ui.picks[slot] = id; delete ui.overrides[slot]; closeSheet(); render(); },
    "map-toggle": () => { ui.showMap = !ui.showMap; render(); },
    "swap-open": swapSheet,
    "cardio-pick": () => { ui.swap = { kind: "cardio", cardio: arg }; swapSheet(); },
    "cardio-minutes": () => { ui.size = arg; swapSheet(); },
    "swap": () => { const [kind, id] = arg.split(":"); ui.swap = kind === "cardio" ? { kind, cardio: id } : { kind, routine: id }; closeSheet(); render(); },
    "swap-clear": () => { ui.swap = null; render(); },
    "start": () => {
      const id = locId();
      const s = previewSession();
      s.defaultSize = defaultSize(); S.lastLocationId = id;
      startSession(s); ui.restStart = null; ui.finish = null; ui.lastTap = null; ui.pausedAt = null; ui.endCued = false; go("session");
    },
    "ex-info": () => exInfo(Number(arg)),
    "ex-swap": () => { const [i, id] = arg.split(":"); swapExercise(S.active, Number(i), id); save(); closeSheet(); render(); },
    "edit": () => { const [what, dir] = arg.split(":"); editStep(what, Number(dir)); },
    "edit-apply": () => editApply(arg),
    "set-done": () => tapSet("done"), "set-short": () => tapSet("short"), "undo": undoSet,
    "rest-skip": () => { ui.restHidden = true; render(); },
    "stop-open": stopSheet,
    "stop": () => { const a = S.active; const idx = a.type === "lift" ? a.exercises.findIndex((e) => e.sets.some((s) => s.outcome === null)) : null; a.stopReason = arg; ui.finish = { stopReason: arg, stopAtExercise: idx }; save(); go("finish"); },
    "bonus-done": () => { S.active.bonusDone = true; save(); ui.finish = {}; go("finish"); },
    "bonus-skip": () => { S.active.bonusDone = true; save(); ui.finish = {}; go("finish"); },
    "move-done": () => { ui.finish = {}; go("finish"); },
    "move-next": () => { S.active.moveIdx++; S.active.moveStart = Date.now(); ui.pausedAt = null; save(); render(); },
    "move-pause": () => { const a = S.active; if (ui.pausedAt) { const gap = Date.now() - ui.pausedAt; if (a.kind === "cardio") a.realStart += gap; else a.moveStart += gap; ui.pausedAt = null; } else ui.pausedAt = Date.now(); save(); render(); },
    "feel": () => doFinish(arg),
    "finish-home": () => { ui.finish = null; go("today"); },
    "cat-pattern": () => { ui.cat.pattern = arg; refreshCatalog(); document.querySelectorAll("[data-act=cat-pattern]").forEach((b) => b.classList.toggle("on", b.dataset.arg === arg)); },
    "cat-info": () => { ev.preventDefault(); catalogInfo(arg); },
    "cat-mode": () => { ui.cat.mode = arg; render(); },
    "cat-category": () => { ui.cat.category = arg; refreshCatalog(); document.querySelectorAll("[data-act=cat-category]").forEach((b) => b.classList.toggle("on", b.dataset.arg === arg)); },
    "chart-toggle": () => { ui.chartTable = !ui.chartTable; render(); },
    "bar": () => { ui.barSel = ui.barSel === Number(arg) ? null : Number(arg); render(); },
    "goal-set": () => { S.profile.goal = arg; rebuildRotation(); for (const [id, t] of Object.entries(S.targets)) { const ex = byId[id]; if (ex) t.reps = rangeFor(ex, PATTERNS[ex.pattern].main ? "main" : "acc", t)[0]; t.topHits = 0; } save(); render(); },
    "days-set": () => { S.profile.daysPerWeek = Number(arg); rebuildRotation(); save(); render(); },
    "units": () => { S.units = arg; save(); render(); },
    "pace": () => { S.pace = arg; S.params = {}; save(); render(); },
    "params-reset": () => { S.params = {}; save(); render(); },
    "loc-del": () => { S.locations = S.locations.filter((l) => l.id !== arg); if (S.lastLocationId === arg) S.lastLocationId = S.locations[0]?.id; save(); render(); },
    "loc-equip": () => { const [id, k] = arg.split(":"); const l = S.locations.find((x) => x.id === id); l.equipment = l.equipment.includes(k) ? l.equipment.filter((x) => x !== k) : [...l.equipment, k]; save(); render(); },
    "loc-all": () => { const [id, on] = arg.split(":"); const l = S.locations.find((x) => x.id === id); l.equipment = on === "on" ? Object.keys(EQUIPMENT) : []; save(); render(); },
    "pause-resume": () => { S.plan.paused[arg].until = 0; save(); render(); },
    "sex": () => { S.profile.sex = arg; save(); render(); },
    "clock": () => { S.clockOffsetDays = arg === "0" ? 0 : (S.clockOffsetDays || 0) + Number(arg); save(); render(); },
    "sim": () => { simulate(Number(arg)); render(); },
    "export": () => { ui.exportOpen = !ui.exportOpen; render(); },
    "import": () => { try { replace(JSON.parse($("[data-input=import]").value)); ui.exportOpen = false; render(); } catch { alert("That is not valid data."); } },
    "reset": () => { if (confirm("Delete everything on this device?")) { reset(); ui.ob = null; ui.size = null; ui.swap = null; ui.picks = {}; ui.overrides = {}; go("today"); } },
  };
  actions[act]?.();
});

document.addEventListener("change", (ev) => {
  const el = ev.target.closest("[data-input]"); if (!el) return;
  const k = el.dataset.input;
  if (k === "loc") { ui.locationId = el.value; ui.picks = {}; ui.overrides = {}; render(); }
  if (k === "param") { S.params[el.dataset.key] = Number(el.value); save(); render(); }
  if (k === "param-off") { if (el.checked) S.params[el.dataset.key] = null; else delete S.params[el.dataset.key]; save(); render(); }
  if (k === "loc-name") { const l = S.locations.find((x) => x.id === el.dataset.id); l.name = el.value || l.name; save(); }
  if (k === "loc-add" && el.value) { const t = TEMPLATES.find((x) => x.id === el.value); S.locations.push({ id: `loc_${Date.now().toString(36)}`, name: t.name, template: t.id, equipment: t.equipment.slice() }); save(); render(); }
  if (k === "dev") { S.dev = el.checked; save(); render(); }
  if (k === "cat-muscle") { ui.cat.muscle = el.value; refreshCatalog(); }
  if (k === "cat-here") { ui.cat.here = el.checked; refreshCatalog(); }
  if (k === "cat-equip") { ui.cat.equip = el.value; refreshCatalog(); }
  if (k === "cat-level") { ui.cat.level = el.value; refreshCatalog(); }
  if (k === "cat-plan") { ui.cat.planOnly = el.checked; refreshCatalog(); }
  if (k === "cat-loc") { ui.locationId = el.value; ui.picks = {}; ui.overrides = {}; refreshCatalog(); }
});
document.addEventListener("input", (ev) => { const el = ev.target.closest("[data-input=cat-q]"); if (!el) return; ui.cat.q = el.value; refreshCatalog(); });
document.addEventListener("toggle", (ev) => { const key = ev.target.dataset?.openKey; if (key) ui.open[key] = ev.target.open; }, true);

// Animations only when the tab is actually visible; a hidden tab never advances them and would leave things at opacity 0.
const syncAnim = () => document.documentElement.classList.toggle("no-anim", document.hidden || !document.hasFocus());
document.addEventListener("visibilitychange", syncAnim); window.addEventListener("focus", syncAnim); window.addEventListener("blur", syncAnim); syncAnim();
render();
