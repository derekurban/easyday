// Persistence and clock. One JSON blob in localStorage. The clock can be shifted for prototype testing.
const KEY = "fitness.v1";
const DAY = 86400000;

export function defaults() {
  return {
    version: 1,
    profile: null,                 // { goal, experience, daysPerWeek, sex, createdAt }
    locations: [],                 // [{ id, name, template, equipment: [] }]
    lastLocationId: null,
    pace: "steady",
    units: "kg",                   // "kg" | "lb" (loads are stored in kg)
    dev: false,                    // prototype tools visible
    params: {},                    // overrides on top of pace + defaults
    plan: null,                    // { rotation, index, baselineSize, extraAccessories, mixShift, floorLowered, offerNormalOnce, offerCooldown, paused: {}, loop2Anchor, firstRotationDone }
    targets: {},                   // exId -> { load, reps, topHits, shortRun, appearances, calibrating }
    person: { comeback: null, lapses: [], lapseMarkedFor: null, nudgedFor: null },
    sessions: [],                  // completed sessions, oldest first
    active: null,                  // in-progress session
    clockOffsetDays: 0,
    seen: {},                      // one-off UI flags
  };
}

export let S = load();

export function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return defaults();
    const parsed = JSON.parse(raw);
    return { ...defaults(), ...parsed };
  } catch { return defaults(); }
}

export function save() { localStorage.setItem(KEY, JSON.stringify(S)); }

export function reset() { S = defaults(); save(); }

export function replace(obj) { S = { ...defaults(), ...obj }; save(); }

export function now() { return Date.now() + (S.clockOffsetDays || 0) * DAY; }

export function daysBetween(a, b) { return Math.floor(Math.abs(b - a) / DAY); }

export function uid() { return Math.random().toString(36).slice(2, 10); }

export function fmtDate(ts) { return new Date(ts).toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" }); }

export function monthKey(ts) { const d = new Date(ts); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`; }

export function lastSession(filter) {
  for (let i = S.sessions.length - 1; i >= 0; i--) if (!filter || filter(S.sessions[i])) return S.sessions[i];
  return null;
}

export function exportJSON() { return JSON.stringify(S, null, 2); }
