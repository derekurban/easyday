# Fitness app

Exercise library with StrengthLog-style muscle highlighting: a front + back body render where the muscles an
exercise works are tinted (red = primary, salmon = secondary).

See `docs/app/APPLICATION.md` for what the app is and how its logic works, with no implementation details.

**Prototype:** `app/` is a mobile-first web app implementing that spec (vanilla ES modules, no build, data in localStorage).
Serve the repo and open `/app/`: `node serve.mjs` (dev) or the `fitness-logic-site` task on port 5180 (Tailscale).
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
| `data/exercises.json` | [free-exercise-db](https://github.com/yuhonas/free-exercise-db): 876 exercises, public domain |
| `docs/` | Muscle-mapping decisions and project history |
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
.venv/Scripts/python make.py      # segment -> remove nipples -> build -> verify (ends with "ALL PASS")
```
Plate -> muscle assignments live in `muscle-map/pipeline/labels.py`.

## Muscle map format (`muscle-map/assets/`)
For each of `male_front`, `male_back`, `female_front`, `female_back` (1254×1254):
- `<view>.png`: the body render (RGBA, transparent background, nipples removed, edge halo cleaned).
- `<view>_ids.png`: **R** = plate id (0 = not a plate), **G** = tint strength 0–255. The tint strength is
  already groove-, seam- and edge-aware, so a renderer just does, per pixel:
  `alpha = G/255 × baseAlpha/255`; `colour = groupColour × (luminance / 182)` (keeps the plate's shading).
- `flat.json`: per view, every plate's `id`, `muscle` name, dataset `group` (or `null` = never highlighted) and centre.
- `outlines.json`: per view, every plate's visible surface (where G is half on) as smooth sub-pixel polygons, from
  `pipeline/outlines.py`. The Android app fills and outlines these as vector paths, so highlights and selection
  outlines stay crisp at any zoom: it draws the render, then per highlighted plate clips to its path and draws the
  render again × `accent × 255/182` at the step's opacity. Copy it to `mobile/assets/muscle/` with the other files.

## References
- `references/style/`: StrengthLog 2D diagrams, the plate-style sheets, MoveKit (look we liked).
- `references/renders/`: the 8 renders the maps are built from (front/back used today; sides kept for later).
- `references/chatgpt-originals/`: the first ChatGPT male turnaround (grey background).
