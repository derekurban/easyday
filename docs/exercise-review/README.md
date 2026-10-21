# The exercise library review, October 2026

How the library went from 137 hand-written exercises to the 324 entries in `data/library.json`, and the record of
every call made on the way. The rules it settled are `docs/app/EXERCISE_DATA.md`; this folder is the history.

## What happened

1. **Import.** Twelve agents each took a batch of free-exercise-db (`data/exercises.json`, public domain) and decided
   every entry: a new exercise, the same as one we had, a new version on a ladder, a stretch, or out. A reconcile pass
   merged the batches, removed duplicates and made the families consistent. Every name and how-to was written in our
   own words.
2. **Muscle tags.** Tagged three times. The first pass tagged by which muscles do the mechanical work, which made a
   ball slam a lat exercise; the owner set the rule that stands: a primary is a great exercise to grow the muscle, a
   secondary grows it slowly, and a muscle used but not strained is left out.
3. **Types.** Every entry was sorted into strength, power, stability, cardio or stretching, and filed by what it is,
   never to fill a gap in coverage. Niche and duplicate exercises were trimmed.
4. **Two-model review.** Every entry was reviewed in eight groups by Claude Opus 5.5 and GPT-6.1-Sol (high effort),
   independently, against a written standard. Where both proposed the same change it was applied (31); the 147 where
   they differed were decided by Claude Fable 5.1 at the owner's request.
5. **Unbiased pass.** GPT-6-Astra saw only the finished list with a neutral legend, no rules and no history, and filed
   139 findings; 46 were accepted.
6. **The owner's last calls** (2026-10-21): power is explosive work (the swing, the push presses and the ball slam
   moved to power); dumbbell loads are always per hand; no hip-flexor region on the body map.

## In this folder

- `REPORT.md`: every change the two-model review applied, before and after, and what it removed.
- `DECISIONS.md`: the 147 disputed findings, each reviewer's position and the decision with its reason.
- `UNBIASED.md`: the unbiased pass, every finding and whether it was taken.

They mention working files (`corpus5.json`, `apply.py`, the review packs) that were removed once the library was
generated into the app; the git history of `data/library.json` starts from their result.
