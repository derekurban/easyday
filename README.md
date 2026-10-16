# Fitness app

Exercise library with StrengthLog-style muscle highlighting: a front + back body render where the muscles an
exercise works are tinted (red = primary, salmon = secondary).

See `docs/app/APPLICATION.md` for what the app is and how its logic works, with no implementation details.

**Prototype:** `app/` is a mobile-first web app implementing that spec (vanilla ES modules, no build, data in localStorage).
Serve the repo and open `/app/`: `node serve.mjs` (dev) or the `fitness-logic-site` task on port 5180 (Tailscale).
The UI uses [derekurban/design-system](https://github.com/derekurban/design-system), vendored at the tag in `app/vendor/du/PINNED_VERSION`;
`app/styles.css` consumes its tokens only. Icons are Lucide (`app/vendor/lucide.min.js`).

## Layout
| Path | What |
|---|---|
| `references/` | Style references and source renders (see below) |
| `muscle-map/assets/` | **Shipped muscle maps**: per view a base image + an id map, plus `flat.json` |
| `muscle-map/pipeline/` | Rebuilds `assets/` from the renders and verifies them pixel-by-pixel |
| `muscle-map/playground/` | Reference renderer: all exercises, male/female, custom highlighting |
| `data/exercises.json` | [free-exercise-db](https://github.com/yuhonas/free-exercise-db): 876 exercises, public domain |
| `docs/` | Muscle-mapping decisions and project history |
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

## References
- `references/style/`: StrengthLog 2D diagrams, the plate-style sheets, MoveKit (look we liked).
- `references/renders/`: the 8 renders the maps are built from (front/back used today; sides kept for later).
- `references/chatgpt-originals/`: the first ChatGPT male turnaround (grey background).
