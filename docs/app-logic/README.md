# App logic

Diagrams of how the habit-first training app is meant to work. Sources are Mermaid in `src/`,
rendered PNGs are in `build/`, and `index.html` is the site.

These diagrams predate 2026-10-19. Anything in them about a rotation, slots or movement patterns is
superseded: workouts are now built per visit from muscles, by `docs/app/SELECTION.md`.

## Viewing over Tailscale
The `easyday-logic-site` scheduled task (per-user, runs at logon) serves the repo on port 5180 via `site.ps1`.
The root redirects to the app:
- App: http://derek-desktop.tail546211.ts.net:5180/app/ (or http://100.105.54.16:5180/app/)
- Diagrams: http://derek-desktop.tail546211.ts.net:5180/docs/app-logic/
- Inspiration board (exercise image styles): http://derek-desktop.tail546211.ts.net:5180/docs/inspiration/

Restart it with `Start-ScheduledTask easyday-logic-site`; run it by hand with `powershell -File docs/app-logic/site.ps1`.
To get HTTPS and a cleaner URL instead, enable Tailscale Serve for the tailnet (the CLI prints an approval link) and run
`tailscale serve --bg D:/Working/easyday/docs/app-logic`.

```
node docs/app-logic/render.mjs                                   # renders src/*.mmd -> build/*.png (headless Edge)
muscle-map/pipeline/.venv/Scripts/python.exe -I docs/app-logic/crop.py   # trims white margins
```

## Diagrams
1. `1-system-map` — inputs, context signals, engines, stores, outputs and what feeds what.
2. `2-session-loop` — one visit to the app, from the two questions to the rotation advance.
3. `3-ladder` — one rule per exercise: rungs, the target shape, step up, step down, never judged.
4. `4-energy-and-time` — how a session is built: time sets the slots, energy fills them by cost.
5. `5-cost-and-decay` — cost drift, rung decay, and the timing model learned from set taps.
6. `6-person-state` — Active / At risk / Away, which drive defaults and reminder tone.
7. `7-automations` — location and calendar triggers and what each changes.

## Design principles (decided 2026-10-14)
Canonical spec: `docs/app/APPLICATION.md` at the repo root. Summary:
- The app optimises for still training a year from now, not for the weight on the bar.
- Undertraining costs a little growth; overtraining costs weeks. Bias toward too easy, ramp slowly.
- The user makes one decision per visit: start or not. Everything else has a default.
- Two questions describe a day: how much energy, and how much time. Nothing else is asked.
- The app may refuse "more". It never refuses "less".
- Progress is earned on a ladder: hit the top of the rep range and the next rung is yours. Step up and step down counts are settings from 1 to 5.
- Every exercise has a cost from 1 to 5. Energy sets the average cost of the session and how hard sets are pushed. Time sets how many exercises and sets fit.
- Energy and time never move a rung. The ladder never changes what is in a session.
- Physical and mental signals are kept apart: a rep count below the top is the only ladder signal; stopping early asks energy, time, or pain.
- Nothing is timed for the user. Seconds per set are learned from the set taps and price the time dial.
- Unused rungs decay gently and re-climb in one clean session. After a week away the day defaults to easy. There is no comeback mode.
- Scheduling is sequence-based: the next session is the next one in the rotation whenever you show up. There is no Tuesday session to miss.
- Cardio and mobility are the floor: deliberately dumb (a duration, a fixed routine) and one tap away.
- Plans think in movement patterns; progress is tracked per exercise; location picks the exercise and how high a bodyweight ladder goes.
- Automations only change defaults and send at most one nudge. They never act for the user.
- Six settings in plain words, plus a cost override per exercise. The guardrails are not settings.
- Progress is shown as sessions per month and rung trend per pattern. Never streaks.
