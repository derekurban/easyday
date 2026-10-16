// The four feedback loops. Run after every session in order 3 → 2 → 1 → 0.
// Each signal has one owner. Slower loops win. Ambiguity holds.
import { S, now, uid, save } from "./store.js";
import { byId, GOALS } from "./library.js";
import { params } from "./params.js";
import { rangeFor, roundStep, rebuildRotation, personState, fmtLoad, patternName, stepFor } from "./planner.js";

// ---------- session start: settle context before anything is judged
export function startSession(session) {
  const ps = personState();
  const p = params();
  session.id = uid();
  session.startedAt = now();
  session.state = ps.state;
  if (ps.state === "lapsed") { S.person.comeback = { done: 0 }; session.comeback = true; }
  else if (ps.state === "comeback") session.comeback = true;
  else session.comeback = false;
  // return-to-normal offer: accepted or declined
  if (S.plan.offerNormalOnce) {
    if (session.size === "small") S.plan.offerCooldown = 2 * p.sizeWindow;
    S.plan.offerNormalOnce = false;
  }
  session.sizeChosenByUser = session.size !== session.defaultSize;
  S.active = session;
  save();
}

// ---------- session end
export function finishSession(session, { feel = null, stopReason = null, stopAtExercise = null } = {}) {
  const p = params();
  session.endedAt = now();
  session.feel = feel;
  session.stopReason = stopReason;
  const lines = [];

  // mark never-started sets as skipped (not attempted)
  if (session.type === "lift") for (const e of session.exercises) for (const s of e.sets) if (s.outcome === null) s.outcome = "skipped";

  loop3(session, p, lines, stopAtExercise);
  if (session.type === "lift") loop2(session, p, lines);
  if (session.type === "lift") loop1(session, p, lines);
  loop0(session, lines);

  session.changes = lines;
  S.sessions.push(session);
  S.active = null;
  // rotation advances whenever a session happens, swapped or not
  S.plan.index = (S.plan.index + 1) % S.plan.rotation.length;
  if (S.plan.index === 0) S.plan.firstRotationDone = true;
  if (S.plan.offerCooldown > 0) S.plan.offerCooldown--;
  save();
  return lines;
}

// ---------- loop 3: per person
function loop3(session, p, lines, stopAtExercise) {
  if (session.comeback && S.person.comeback && session.type === "lift") {   // movement keeps the habit; lifting restores the loads
    S.person.comeback.done++;
    if (S.person.comeback.done >= p.comebackSessions) { S.person.comeback = null; lines.push("Comeback complete. Loads are back where they were."); }
    else lines.push(`Comeback ${S.person.comeback.done} of ${p.comebackSessions}. A little more load next time.`);
  }
  if (session.stopReason === "pain" && session.type === "lift") {
    const e = session.exercises[stopAtExercise ?? 0];
    if (e) {
      S.plan.paused[e.pattern] = { until: now() + p.painPauseDays * 86400000, since: now() };
      lines.push(`${patternName(e.pattern)} is paused for ${p.painPauseDays} days. It comes back lighter.`);
    }
  }
  // floor lowering: repeated lapses
  if (p.lapsesBeforeFloor !== null && !S.plan.floorLowered) {
    const recent = S.person.lapses.filter((t) => now() - t < 56 * 86400000).length;
    if (recent >= p.lapsesBeforeFloor) {
      S.plan.floorLowered = true; rebuildRotation();
      lines.push("The plan just got easier to keep: shorter sessions, more movement days.");
    }
  }
}

// ---------- loop 2: per plan
function liftWindow(n) {
  const out = [];
  for (let i = S.sessions.length - 1; i >= S.plan.loop2Anchor && out.length < n; i--) {
    const s = S.sessions[i];
    if (s.type === "lift" && !s.comeback) out.push(s);
  }
  return out;
}

function clean(s) {
  return s.stopReason === null && s.feel !== "too_much" && !s.exercises.some((e) => e.sets.some((x) => x.outcome === "short"));
}

function loop2(session, p, lines) {
  if (session.comeback) return;                       // invisible to loop 2
  const win = liftWindow(p.sizeWindow);
  const act = (msg) => { S.plan.loop2Anchor = S.sessions.length + 1; lines.push(msg); };
  if (win.length + 1 >= p.sizeWindow) {               // +1: the session being finished isn't pushed yet
    const all = [session, ...win].slice(0, p.sizeWindow);
    const smallPicks = all.filter((s) => s.sizeChosenByUser && s.size === "small").length;
    const normalPicks = all.filter((s) => s.sizeChosenByUser && s.size === "normal").length;
    const energy = all.filter((s) => s.size === "normal" && s.stopReason === "energy").length;
    const bigDone = all.filter((s) => s.size === "big" && s.stopReason === null && !s.exercises.some((e) => e.sets.some((x) => x.outcome !== "done"))).length;
    if (S.plan.baselineSize !== "small" && smallPicks >= p.sizePicks) { S.plan.baselineSize = "small"; act(`Sessions default to small now: you chose small ${smallPicks} of the last ${all.length}.`); }
    else if (S.plan.baselineSize !== "small" && energy >= p.energyStops) { S.plan.baselineSize = "small"; act(`Sessions default to small now: ${energy} of the last ${all.length} ended on energy.`); }
    else if (S.plan.baselineSize === "small" && normalPicks >= p.sizePicks) { S.plan.baselineSize = "normal"; act(`Sessions default to normal again: you chose normal ${normalPicks} of the last ${all.length}.`); }
    else if (bigDone >= p.sizePicks && S.plan.extraAccessories < 2) { S.plan.extraAccessories++; act("One more accessory in normal sessions: you finished big ones repeatedly."); }
  }
  // swaps: more than half of the last rotation
  const rotLen = S.plan.rotation.length;
  const recent = [session, ...S.sessions.slice(-rotLen + 1).reverse()].slice(0, rotLen);
  const swaps = recent.filter((s) => s.swapped).length;
  if (recent.length >= rotLen && swaps > rotLen / 2 && S.plan.mixShift < rotLen - 1) {
    S.plan.mixShift++; rebuildRotation(); lines.push("One lifting day became a movement day: that is what you kept choosing.");
  }
  // return path
  if (S.plan.baselineSize === "small" && p.cleanBeforeOffer !== null && S.plan.offerCooldown === 0 && !S.plan.offerNormalOnce) {
    const last = [session, ...liftWindow(p.cleanBeforeOffer - 1)];
    if (last.length >= p.cleanBeforeOffer && last.every(clean)) { S.plan.offerNormalOnce = true; lines.push("Next session defaults to normal: the last few small ones were clean. Small is still one tap away."); }
  }
}

// ---------- loop 1: per exercise
function loop1(session, p, lines) {
  const goal = GOALS[S.profile.goal];
  const calibratingRotation = !S.plan.firstRotationDone;
  const energyOrTime = session.stopReason === "energy" || session.stopReason === "time";
  for (const e of session.exercises) {
    const ex = byId[e.exId];
    const t = S.targets[e.exId];
    const attempted = e.sets.filter((s) => s.outcome !== "skipped");
    if (!attempted.length || !t) continue;
    t.appearances++;
    const range = rangeFor(ex, e.role, t);
    const anyShort = attempted.some((s) => s.outcome === "short");
    const allScheduledDone = e.sets.every((s) => s.outcome === "done");
    const avgRest = e.rests.length ? e.rests.reduce((a, b) => a + b, 0) / e.rests.length : 0;
    const restBlock = p.restSlack !== null && e.rests.length > 0 && avgRest > p.restSlack * e.rest;
    const name = ex.name;
    const stepLoad = stepFor(ex);

    if (anyShort || session.feel === "too_much") {
      t.topHits = 0;
      if (anyShort) {
        t.shortRun++;
        if (t.shortRun >= p.shortBeforeDown) {
          if (t.reps > range[0]) { t.reps--; lines.push(`${name}: ${t.reps} reps next time. Two short appearances in a row.`); }
          else { t.load = Math.max(0, roundStep(t.load - stepLoad, stepLoad)); lines.push(`${name}: down to ${fmtLoad(ex, t.load)}. Lighter and clean beats heavy and short.`); }
          t.shortRun = 0;
        } else lines.push(`${name}: held. A set came up short.`);
      } else lines.push(`${name}: held. You said too much.`);
      continue;
    }
    t.shortRun = 0;
    if (session.comeback) { continue; }                                          // guardrail: never up in comeback
    if (!allScheduledDone) { if (energyOrTime) lines.push(`${name}: held. Finish it next time and it moves.`); continue; }  // momentum gate
    if (restBlock) { lines.push(`${name}: held. Rests ran long.`); continue; }
    const atTop = t.reps >= range[1];
    if ((calibratingRotation || t.calibrating) && session.feel === "easy" && atTop) {
      t.load = roundStep(t.load + stepLoad, stepLoad); t.reps = rangeFor(ex, e.role, t)[0]; t.topHits = 0; t.calibrating = false;
      lines.push(`${name}: up to ${fmtLoad(ex, t.load)} straight away. Easy at the top of the range while we calibrate.`);
      continue;
    }
    t.calibrating = false;
    if (!atTop) { t.reps++; t.topHits = 0; lines.push(`${name}: ${t.reps} reps next time.`); continue; }
    t.topHits++;
    if (t.topHits >= p.confirmations) {
      t.load = roundStep(t.load + stepLoad, stepLoad); t.reps = rangeFor(ex, e.role, t)[0]; t.topHits = 0;
      lines.push(ex.unit === "bw" ? `${name}: harder next time, ${t.reps} to ${rangeFor(ex, e.role, t)[1]} reps. You held the top of the range.`
        : `${name}: up to ${fmtLoad(ex, t.load)}. You hit ${range[1]} on every set ${p.confirmations === 1 ? "" : p.confirmations + " times"}.`);
    } else lines.push(`${name}: one more like that and it goes up.`);
  }
  void goal;
}

// ---------- loop 0: to the human
function loop0(session, lines) {
  if (session.type === "move") {
    lines.unshift(session.kind === "cardio" ? `${session.minutes} minutes of movement. That counts.` : "Mobility done. That counts.");
    return;
  }
  const done = session.exercises.flatMap((e) => e.sets).filter((s) => s.outcome === "done").length;
  const total = session.exercises.flatMap((e) => e.sets).length;
  lines.unshift(session.stopReason ? `Stopped early. ${done} of ${total} sets done, and that still counts.` : `${done} of ${total} sets done.`);
}
