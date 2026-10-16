// Builds today's session from plan state, location, size, picks, and person state.
import { S, now, daysBetween, lastSession } from "./store.js";
import { EXERCISES, byId, available, GOALS, PATTERNS, buildRotation, MOVE, ROUTINES } from "./library.js";
import { params } from "./params.js";

export const SIZES = ["small", "normal", "big"];
const LB = 2.20462;

export function location(id) { return S.locations.find((l) => l.id === id) ?? S.locations[0]; }

export function roundStep(x, step) { return Math.round(x / step) * step; }

// ---------- units. Loads are stored in kg; steps and display follow the chosen unit.
export function stepFor(ex) {
  if (ex.unit === "bw") return 1;
  if (S.units === "lb") return (ex.step >= 5 ? 10 : 5) / LB;
  return ex.step;
}
export function fmtLoad(ex, load) {
  if (ex.unit === "bw") return "bodyweight";
  if (S.units === "lb") { const lb = Math.round(load * LB / 2.5) * 2.5; return `${lb % 1 ? lb.toFixed(1) : lb} lb${ex.each ? " each" : ""}`; }
  return `${load % 1 ? load.toFixed(1) : load} kg${ex.each ? " each" : ""}`;
}
export function fmtNum(load) { if (S.units === "lb") { const lb = Math.round(load * LB / 2.5) * 2.5; return `${lb % 1 ? lb.toFixed(1) : lb}`; } return `${load % 1 ? load.toFixed(1) : load}`; }
export function unitLabel() { return S.units === "lb" ? "lb" : "kg"; }

// ---------- person state (loop 3, read side)
export function personState() {
  const p = params();
  const last = lastSession();
  if (!last) return { state: "active", daysSince: 0, last: null };
  const daysSince = daysBetween(last.endedAt, now());
  let state = "active";
  if (daysSince >= p.lapsedDays) state = "lapsed";
  else if (S.person.comeback) state = "comeback";
  else if (daysSince >= p.atRiskDays) state = "at_risk";
  if (state === "lapsed" && S.person.lapseMarkedFor !== last.id) {
    S.person.lapses.push(now());
    S.person.lapseMarkedFor = last.id;
    if (S.person.comeback) S.person.comeback = null;
  }
  return { state, daysSince, last };
}

export const STATE_LABEL = { active: "Active", at_risk: "At risk", lapsed: "Lapsed", comeback: "Comeback" };

// ---------- targets
export function rangeFor(ex, role, target) {
  if (ex.unit === "bw") { const lvl = target?.load ?? 0; return [ex.range[0] + 2 * lvl, ex.range[1] + 2 * lvl]; }
  const g = GOALS[S.profile.goal];
  return role === "main" ? g.main : g.acc;
}

function startLoad(ex) {
  if (ex.unit === "bw") return 0;
  const exp = S.profile.experience;
  let load = ex.start[exp];
  const known = EXERCISES.filter((e) => e.pattern === ex.pattern && e.id !== ex.id && e.unit === "kg" && S.targets[e.id]?.appearances > 0)
    .map((e) => ({ e, t: S.targets[e.id] })).sort((a, b) => b.t.appearances - a.t.appearances)[0];
  if (known) load = load * Math.min(2, Math.max(0.5, known.t.load / known.e.start[exp]));
  return roundStep(load, stepFor(ex));
}

export function ensureTarget(ex, role) {
  let t = S.targets[ex.id];
  if (!t) {
    t = { load: startLoad(ex), reps: rangeFor(ex, role, { load: 0 })[0], topHits: 0, shortRun: 0, appearances: 0, calibrating: true };
    S.targets[ex.id] = t;
  }
  return t;
}

// A manual edit of the saved target. The loops keep working from here.
export function setTarget(exId, { load, reps }) {
  const t = S.targets[exId]; if (!t) return;
  if (load != null) t.load = Math.max(0, load);
  if (reps != null) t.reps = Math.max(1, reps);
  t.topHits = 0; t.shortRun = 0; t.calibrating = false;
}

// Warm-up suggestion for a loaded main lift: two lighter sets, never logged.
export function warmups(ex, load) {
  if (ex.unit !== "kg") return [];
  const step = stepFor(ex);
  const half = roundStep(load * 0.5, step), three = roundStep(load * 0.75, step);
  if (half < step * 2 || three >= load) return [];
  return [{ reps: 8, load: half }, { reps: 5, load: three }];
}

// ---------- exercise selection
export function candidates(pattern, equipment, exclude = []) {
  return EXERCISES.filter((e) => e.pattern === pattern && available(e, equipment) && !exclude.includes(e.id));
}

export function pickExercise(pattern, equipment, exclude = [], preferred = null) {
  const cands = candidates(pattern, equipment, exclude);
  if (!cands.length) return null;
  if (preferred) { const p = cands.find((e) => e.id === preferred); if (p) return p; }
  cands.sort((a, b) => {
    const ha = S.targets[a.id]?.appearances ?? 0, hb = S.targets[b.id]?.appearances ?? 0;
    if ((hb > 0) !== (ha > 0)) return hb > 0 ? 1 : -1;
    return a.rank - b.rank;
  });
  return cands[0];
}

export function alternatives(pattern, equipment, currentId) { return candidates(pattern, equipment, [currentId]); }

export function shufflePicks(session, equipment) {
  const picks = {};
  const used = [];
  for (const e of session.exercises) {
    const alts = candidates(e.pattern, equipment, [...used, e.exId]).sort((a, b) => a.rank - b.rank);
    const pool = (alts.length ? alts : candidates(e.pattern, equipment, used)).slice(0, 4);
    const pick = pool[Math.floor(Math.random() * pool.length)] ?? byId[e.exId];
    picks[e.slot] = pick.id; used.push(pick.id);
  }
  return picks;
}

export function sessionMuscles(session) {
  const p = new Set(), s = new Set();
  for (const e of session.exercises ?? []) { const ex = byId[e.exId]; ex.m.p.forEach((m) => p.add(m)); ex.m.s.forEach((m) => s.add(m)); }
  for (const m of p) s.delete(m);
  return { primary: [...p], secondary: [...s] };
}

// ---------- rotation
export function rebuildRotation() {
  const plan = S.plan;
  plan.rotation = buildRotation(S.profile.goal, S.profile.daysPerWeek, { mixShift: plan.mixShift, floorLowered: plan.floorLowered });
  plan.index = plan.index % plan.rotation.length;
}

export function initPlan() {
  S.plan = { rotation: [], index: 0, baselineSize: "normal", extraAccessories: 0, mixShift: 0, floorLowered: false, offerNormalOnce: false, offerCooldown: 0, paused: {}, loop2Anchor: 0, firstRotationDone: false };
  rebuildRotation();
}

// The cycle as the user sees it: every item, which is next, and what it emphasises.
export function cycleView() {
  return S.plan.rotation.map((r, i) => ({
    index: i, current: i === S.plan.index, type: r.type, kind: r.kind ?? null, name: r.name,
    detail: r.type === "lift" ? r.mains.map((m) => PATTERNS[m].name.toLowerCase()).join(", ") : (r.kind === "cardio" ? "easy cardio" : "mobility"),
    icon: r.type === "lift" ? "dumbbell" : r.kind === "cardio" ? "footprints" : "stretch-horizontal",
  }));
}

function expirePauses() {
  const p = params();
  for (const [pattern, pause] of Object.entries(S.plan.paused)) {
    if (now() >= pause.until) {
      for (const e of EXERCISES) if (e.pattern === pattern && S.targets[e.id] && e.unit === "kg") S.targets[e.id].load = roundStep(S.targets[e.id].load * p.comebackFactor, stepFor(e));
      delete S.plan.paused[pattern];
    }
  }
}

export function currentItem() { return S.plan.rotation[S.plan.index]; }

export function defaultSize() { return S.plan.offerNormalOnce ? "normal" : S.plan.baselineSize; }

// ---------- session construction
// picks: { slot -> exId } overrides for this session. overrides: { slot -> { load?, reps? } } manual edits for today.
export function buildSession({ size, locationId, swap = null, picks = {}, overrides = {} }) {
  expirePauses();
  const item = currentItem();
  const p = params();
  const ps = personState();
  const comeback = ps.state === "lapsed" || ps.state === "comeback";
  const loc = location(locationId);
  const goal = GOALS[S.profile.goal];
  const base = { itemIndex: S.plan.index, itemName: item.name, locationId: loc?.id ?? null, size, comeback, state: ps.state, swapped: false };

  if (swap || item.type === "move") {
    const kind = swap?.kind ?? item.kind;
    const minutes = size === "small" ? 10 : size === "big" ? 30 : 20;
    const routineId = swap?.routine ?? item.routine ?? "reset";
    return { ...base, type: "move", kind, swapped: item.type === "lift", minutes: kind === "cardio" ? minutes : null, cardio: swap?.cardio ?? "any", routine: kind === "mobility" ? routineId : null, name: kind === "cardio" ? "Move day" : ROUTINES[routineId].name };
  }

  const equipment = loc?.equipment ?? [];
  let mains = item.mains.slice();
  let accs = item.accs.slice();
  const free = (list) => list.find((a) => !mains.includes(a) && !accs.includes(a) && !S.plan.paused[a] && candidates(a, equipment).length);
  mains = mains.map((m) => (S.plan.paused[m] ? free(["core", "carry", "arms", "legs"]) : m)).filter(Boolean);
  accs = accs.filter((a) => !S.plan.paused[a]);
  for (let i = 0; i < S.plan.extraAccessories; i++) { const extra = free(["core", "arms", "shoulders", "legs", "carry"]); if (extra) accs.push(extra); }
  let bonus = null;
  if (size === "small") accs = [];
  if (size === "big") {
    const extra = free(["shoulders", "arms", "legs", "core", "carry"]);
    bonus = goal.moveEvery <= 2 || !extra ? { kind: "cardio", minutes: 8 } : { kind: "accessory", pattern: extra };
    if (bonus.kind === "accessory") accs.push(extra);
  }

  const used = [];
  const exercises = [];
  const counts = {};
  const add = (pattern, role) => {
    const slot = `${pattern}${counts[pattern] = (counts[pattern] ?? 0) + 1}`;
    const ex = pickExercise(pattern, equipment, used, picks[slot]);
    if (!ex) return;
    used.push(ex.id);
    const t = ensureTarget(ex, role);
    const range = rangeFor(ex, role, t);
    let load = t.load, reps = t.reps, scaled = false;
    if (comeback && ex.unit === "kg") {
      const done = S.person.comeback?.done ?? 0;
      load = roundStep(t.load * (p.comebackFactor + (1 - p.comebackFactor) * (done / p.comebackSessions)), stepFor(ex)); reps = range[0]; scaled = true;
    }
    const o = overrides[slot];
    if (o) { if (o.load != null) load = o.load; if (o.reps != null) reps = o.reps; }
    const sets = role === "main" ? (size === "small" ? 2 : 3) : 2;
    exercises.push({ slot, exId: ex.id, pattern, role, sets: Array.from({ length: sets }, () => ({ outcome: null })), target: { load, reps }, range, rest: goal.rest, scaled, edited: !!o, rests: [] });
  };
  mains.forEach((m) => add(m, "main"));
  accs.forEach((a) => add(a, "acc"));
  return { ...base, type: "lift", name: item.name, focus: item.focus, exercises, bonus: bonus?.kind === "cardio" ? bonus : null, bonusPattern: bonus?.kind === "accessory" ? bonus.pattern : null };
}

export function swapExercise(session, idx, newExId) {
  const ex = byId[newExId];
  const e = session.exercises[idx];
  const t = ensureTarget(ex, e.role);
  const range = rangeFor(ex, e.role, t);
  const p = params();
  let load = t.load, reps = t.reps, scaled = false;
  if (session.comeback && ex.unit === "kg") {
    const done = S.person.comeback?.done ?? 0;
    load = roundStep(t.load * (p.comebackFactor + (1 - p.comebackFactor) * (done / p.comebackSessions)), stepFor(ex)); reps = range[0]; scaled = true;
  }
  session.exercises[idx] = { ...e, exId: ex.id, target: { load, reps }, range, scaled, edited: false, sets: e.sets.map(() => ({ outcome: null })), rests: [] };
}

export function patternName(p) { return PATTERNS[p]?.name ?? p; }
export { MOVE, ROUTINES };
