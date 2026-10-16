// Loop parameters, pace presets, and the guardrails that no setting can change.
// Written for someone who has never heard the word "loop": each group says what it does in one sentence.
import { S } from "./store.js";

export const GROUPS = [
  { loop: 1, title: "How weight goes up and down", icon: "trending-up",
    blurb: "Reps climb first. Once you hit the top of the rep range enough times in a row, the weight steps up and reps start over at the bottom. A short set holds everything; two short appearances in a row bring it down." },
  { loop: 2, title: "How sessions resize", icon: "scaling",
    blurb: "The app watches which size you pick and how often you run out of energy. If small keeps winning, small becomes the default. A run of clean small sessions earns an offer to go back to normal." },
  { loop: 3, title: "Breaks and comebacks", icon: "sunrise",
    blurb: "A few days away gets one gentle nudge. A week away makes the next session a comeback: lighter and shorter, ramping back over a few sessions. Something hurting rests that movement pattern for a while." },
];

export const PARAMS = [
  { key: "confirmations", loop: 1, name: "Top-of-range sessions before the weight goes up", def: 2, min: 1, max: 4, step: 1, unit: "sessions" },
  { key: "shortBeforeDown", loop: 1, name: "Short appearances in a row before reps or weight come down", def: 2, min: 1, max: 3, step: 1, unit: "appearances" },
  { key: "restSlack", loop: 1, name: "Rests this much longer than planned block an increase", def: 1.5, min: 1.2, max: 2.0, step: 0.1, unit: "× planned rest", off: true },
  { key: "sizeWindow", loop: 2, name: "Recent sessions the app looks at", def: 4, min: 3, max: 8, step: 1, unit: "sessions" },
  { key: "sizePicks", loop: 2, name: "Times you pick a size in that window before it becomes the default", def: 3, min: 2, max: 8, step: 1, unit: "picks" },
  { key: "energyStops", loop: 2, name: "Energy stops in that window before sessions shrink", def: 2, min: 1, max: 8, step: 1, unit: "stops" },
  { key: "cleanBeforeOffer", loop: 2, name: "Clean small sessions before normal is offered again", def: 4, min: 2, max: 8, step: 1, unit: "sessions", off: true },
  { key: "atRiskDays", loop: 3, name: "Days away before a gentle nudge", def: 3, min: 2, max: 7, step: 1, unit: "days" },
  { key: "lapsedDays", loop: 3, name: "Days away before the next session is a comeback", def: 7, min: 5, max: 21, step: 1, unit: "days" },
  { key: "comebackSessions", loop: 3, name: "Sessions a comeback takes", def: 3, min: 1, max: 5, step: 1, unit: "sessions" },
  { key: "comebackFactor", loop: 3, name: "Comeback starting weight, as a share of your target", def: 0.85, min: 0.7, max: 0.95, step: 0.05, unit: "× target" },
  { key: "lapsesBeforeFloor", loop: 3, name: "Breaks in eight weeks before the plan gets easier to keep", def: 3, min: 2, max: 5, step: 1, unit: "breaks", off: true },
  { key: "painPauseDays", loop: 3, name: "Days a movement pattern rests after something hurts", def: 7, min: 3, max: 28, step: 1, unit: "days" },
];

export const PACE = {
  gentle: { name: "Gentle", blurb: "Weight goes up after three clean sessions at the top of the range. One short set brings reps down. Comebacks start at 80 percent and take four sessions.", set: { confirmations: 3, shortBeforeDown: 1, sizeWindow: 6, sizePicks: 4, comebackFactor: 0.8, comebackSessions: 4 } },
  steady: { name: "Steady", blurb: "Weight goes up after two clean sessions at the top of the range. Two short appearances bring reps down. Comebacks start at 85 percent and take three sessions.", set: {} },
  eager: { name: "Eager", blurb: "Weight goes up the first time you hit the top of the range. Three short appearances before reps come down. Comebacks start at 90 percent and take two sessions.", set: { confirmations: 1, shortBeforeDown: 3, sizeWindow: 3, sizePicks: 2, comebackFactor: 0.9, comebackSessions: 2 } },
};

export const GUARDRAILS = [
  "A short set, or a too-much tap, always holds. Weight never goes up on an appearance with either.",
  "Weight never goes up during a comeback.",
  "Weight never goes up on an appearance with an energy or time stop.",
  "Size changes how much you do, never how heavy.",
  "A comeback always starts lighter. The factor cannot reach 1.0.",
  "At most one reminder per change of state.",
  "The app may refuse \"more\". It never refuses \"less\".",
];

export function params() {
  const out = {};
  for (const p of PARAMS) out[p.key] = p.def;
  Object.assign(out, PACE[S.pace]?.set ?? {});
  for (const [k, v] of Object.entries(S.params || {})) {
    const def = PARAMS.find((p) => p.key === k);
    if (!def) continue;
    if (v === null && def.off) { out[k] = null; continue; }
    out[k] = Math.min(def.max, Math.max(def.min, Number(v)));
  }
  return out;
}
