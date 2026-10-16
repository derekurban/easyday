# Muscle mapping

## Exercise data vocabulary
free-exercise-db tags each exercise with `primaryMuscles` / `secondaryMuscles` from 17 groups:

abdominals, abductors, adductors, biceps, calves, chest, forearms, glutes, hamstrings, lats, lower back,
middle back, neck, quadriceps, shoulders, traps, triceps

## How plates map to groups (`muscle-map/pipeline/labels.py`)
Each render has 38–48 plates. Every plate has a specific muscle name (shown on hover) and the dataset group it
counts toward. Notable decisions:

| Plates | Group | Why |
|---|---|---|
| Front, side, rear deltoid | shoulders | Dataset has one shoulder group (see "Next" below) |
| Serratus anterior, external obliques | abdominals | Dataset has no serratus/oblique group |
| Infraspinatus & teres | middle back | Closest dataset group |
| Tensor fasciae latae, gluteus medius | abductors | Hip abductors |
| Tibialis anterior (front shins) | none | Not in the dataset; never highlighted |
| — | neck | No plate on the renders; neck exercises show no highlight |

## Verification (`muscle-map/pipeline/verify.py`)
Run on every rebuild; all four maps must pass:
- **No islands**: a plate's tint is one connected piece (never jumps a groove).
- **Seams in the valley**: where two plates touch, the boundary is on the darkest line of the groove.
- **Coverage**: every light plate pixel is tinted. Known, intentional exceptions: 1–8 px specular glints on the
  dark head/toes/grooves, and a 4–6 px hairline seam on the female upper arms.

Source-art quirk: a tiny dark smudge on the male's right front calf plate is in the render itself.

## Next: per-head deltoids (decided: hand-curate)
The 338 shoulder exercises (129 primary) don't say which deltoid head they work. Plan: draft a per-head
assignment from exercise names (front raise / Arnold / military → front; lateral raise / upright row → side;
rear delt / face pull / reverse fly → rear; compound presses → front + side), then review it by hand as a table.
The same approach can split serratus/obliques out of "abdominals".
