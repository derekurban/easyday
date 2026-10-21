# Easyday

Exercise library with StrengthLog-style muscle highlighting: a front + back body render where the muscles an
exercise works are tinted (red = primary, salmon = secondary).

See `docs/app/APPLICATION.md` for what the app is and how its logic works, with no implementation details.

**Prototype:** `app/` is a mobile-first web app implementing that spec (vanilla ES modules, no build, data in localStorage).
Serve the repo and open `/app/`: `node serve.mjs` (dev) or the `easyday-logic-site` task on port 5180 (Tailscale).
The UI uses [derekurban/design-system](https://github.com/derekurban/design-system), vendored at the tag in `app/vendor/du/PINNED_VERSION`;
`app/styles.css` consumes its tokens only. Icons are Lucide (`app/vendor/lucide.min.js`).

**Android app:** `mobile/` is the Flutter build of the same spec, the one in daily use. Its dev loop, flavours,
releases and in-app updates are in `mobile/README.md`.

## Branches and releases
Work lands on `dev`. Merging `dev` into `staging` builds and publishes a staging release on GitHub; merging `staging`
into `main` does the same for prod (`.github/workflows/release.yml`). Installed apps find the newest release for
their flavour and update themselves. Open a pull request for each merge: it runs the same build as a check, and the
merge publishes. Details: `mobile/README.md`, "Branches and releases" and "Updates in the app".

## Layout
| Path | What |
|---|---|
| `references/` | Style references and source renders (see below) |
| `muscle-map/assets/` | **Shipped muscle maps**: per view a base image + an id map, plus `flat.json` |
| `muscle-map/pipeline/` | Rebuilds `assets/` from the renders and verifies them pixel-by-pixel |
| `muscle-map/playground/` | Reference renderer: all exercises, male/female, custom highlighting |
| `data/library.json` | **The app's exercise library**: 324 exercises, stretches and cardio choices. Edit it, then `python mobile/tool/gen_library.py`; the rules are `docs/app/EXERCISE_DATA.md` |
| `data/exercises.json` | [free-exercise-db](https://github.com/yuhonas/free-exercise-db): 876 exercises, public domain; the playground's data and a source the library drew on |
| `docs/` | The app spec (`docs/app/`), muscle-mapping decisions, project history, and the 2026 exercise review record (`docs/exercise-review/`) |
| `mobile/` | The Android app (Flutter): `lib/` code, `test/`, `android/`, `tool/` dev scripts |
| `.github/workflows/` | `release.yml`: staging and prod releases on merge |
| `app/` | Mobile prototype: onboarding, today, session, progress, settings. Logic in `app/js/{planner,loops,params}.js`; illustrations in `app/art/` (monoline SVGs generated with Codex, see `app/art/manifest.json`) |
| `docs/inspiration/` | Inspiration board: exercise demonstration images in several styles, generated with the Codex image tool from `styles.json` |
| `docs/app-logic/` | App logic diagrams (system map, session loop, feedback loops, states, automations) + design principles |

## Run the playground
```
node serve.mjs          # http://localhost:5179/muscle-map/playground/
```

## Rebuild the muscle maps
```
cd muscle-map/pipeline
python -m venv .venv && .venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/python make.py      # segment -> build -> verify -> outlines (ends with "ALL PASS")
```
Plate -> muscle assignments live in `muscle-map/pipeline/labels.py`.

## Muscle map format (`muscle-map/assets/`)
For each of `male_front`, `male_back`, `female_front`, `female_back` (1254×1254):
- `<view>.png`: the body render (RGBA, transparent background, nipples removed, edge halo cleaned, silhouette
  smoothed so an enlarged figure has no serrated edge; `pipeline/verify.py` checks it).
- `<view>_ids.png`: **R** = plate id (0 = not a plate), **G** = tint strength 0–255. The tint strength is
  already groove-, seam- and edge-aware, so a renderer just does, per pixel:
  `alpha = G/255 × baseAlpha/255`; `colour = groupColour × (luminance / 182)` (keeps the plate's shading).
- `flat.json`: per view, every plate's `id`, anatomical `muscle`, everyday `name` (what the Android app tags exercises
  with, highlights by and shows on a tap; `pipeline/labels.py` `NAMES`), dataset `group` (or `null` = never
  highlighted; what the playground uses) and centre.
- `outlines.json`: per view and plate, two smooth sub-pixel polygon sets from `pipeline/outlines.py`. `plates` is
  the plate's visible edge (for a renderer that outlines plates; the fills are grown from it): it runs out to where the render drops into the groove,
  measured against the plate's own nearby brightness so shaded rims (the outer calves) are in; light strips and tips
  beside the plate are taken in, narrow creases inside it closed, and the curve smoothed along its length (lightly at
  tips, more along the silhouette). `fills` is that edge grown a pixel into the groove, never onto another plate
  (what a highlight fills: multiplying the near-black groove changes nothing visible, so the fill covers the edge's
  anti-aliasing completely). `pipeline/check_outlines.py` gates both: no notches, every light pixel of a plate
  covered, each outline inside its fill, no fill on a neighbour. The Android app draws the render, then per
  highlighted plate clips to its fill and draws the render again × `accent × 255/182` at the step's opacity; a
  tapped group fills the same way in blue at full strength, in place of its step. Copy it to `mobile/assets/muscle/` with the other files.

## References
- `references/style/`: StrengthLog 2D diagrams, the plate-style sheets, MoveKit (look we liked).
- `references/renders/`: the 8 renders the maps are built from (front/back used today; sides kept for later).
- `references/chatgpt-originals/`: the first ChatGPT male turnaround (grey background).
