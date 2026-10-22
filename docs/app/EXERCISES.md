# Exercises

An exercise is a named movement with a progression: the list of levels it can get harder by. The library is
built in and fixed for now. How the library is organised for browsing is the user's choice, from a few
pre-made indexes.

## What it is

Every exercise has the same shape:

- **A name.** "Push-ups", "Barbell back squat", "Towel row".
- **A type.** What it is: **strength** (builds muscle), **power** (explosive work), **stability** (control and
  light holds), **cardio** (kept going for time) or **stretching** (range of motion). Only strength exercises are
  picked for a workout's muscles; the types and their tests are in `EXERCISE_DATA.md`.
- **How it gets harder.** One of two ways.
  - *By weight.* The level is the working weight in the exercise's home reps, and each level is one plate
    step: 155 lb, 160, 165. A day with other reps carries it there, heavier and fewer or lighter and more,
    the same level. Barbells, dumbbells, machines, kettlebells. The description stays the same; only the
    number moves.
  - *By version.* A written list of levels, easiest first: wall push-ups, incline, knee, full, feet
    elevated, archer. Bodyweight and bands. Where loading gear exists (vest, dip belt, backpack), levels
    above the top version add weight to it.
- **A how-to at every level.** By-version exercises carry a description per level, so when the level
  changes, the instructions change with it. A pause or tempo level folds its cue into the base text; a band
  level names the band.
- **A difficulty: easy, medium or hard.** How much one hard set takes out of the whole body. The library
  carries a finer number underneath (the rubric: how much muscle moves, plus the spine or the arms carrying
  the load, plus a load that can get heavy) and folds it to three. A hard day pushes the hard ones first;
  easier exercises get more reps and less weight. It can be overridden on the card.
- **What it needs.** Equipment that must be at the location. Nothing, for most bodyweight moves.
- **Muscles.** A primary list and a secondary list, from the twenty names below. The primary muscles are
  what selection picks it for.
- **A preference.** Liked, fine or not for me, the user's own word; unrated until they say. See
  `SELECTION.md`.
- **How its weight reads.** Dumbbells and kettlebells per hand ("12 kg per hand"), a one-limb cable load per side,
  a bar as its total ("40 kg"), a Smith machine or landmine as the plates added ("+20 kg", or "empty bar"), and the
  assisted pull-up machine as its help ("30 kg assistance", less with every level). An exercise that takes a bar or
  dumbbells shows dumbbells per hand where the location only has dumbbells.
- **Reps or seconds.** Most count reps. Holds (plank, wall sit, handstand hold) count seconds and have
  their own ranges.

## The library

A built-in set of 324 entries, reviewed in October 2026 (`docs/exercise-review/`): 224 strength exercises, 14 power,
22 stability, 16 cardio and 48 stretches. The strength exercises cover every muscle at the common equipment levels
(barbell, dumbbell, kettlebell, cable, machine, band, suspension, and nothing at all), though not every muscle at
every location: an exercise is filed by what it is, never to fill a gap, and the builder skips a muscle nothing here
trains. Loaded movements are standalone exercises; bodyweight movements are versions on one progression, so chin-ups
and pull-ups are two exercises while knee push-ups and push-ups are two levels of one.

Strength, power and stability exercises have levels and a card, and the catalog lists all three. Only strength is
built into workouts today; power and stability wait for the warm-up. The stretches make up the stretching routines
and the steady cardio entries are the cardio choices of a movement day.

The library is data, `data/library.json`, generated into the app by `mobile/tool/gen_library.py`; what every field
means and when it is right is `EXERCISE_DATA.md`. A version can move to its own exercise, or an exercise fold into a
progression, when real use says so. Users cannot add exercises yet; that is deliberate scope, not a gap.

## Indexes

An index is a way of grouping the library. The user picks one and the catalog, the swap sheet and progress
all group by it. The exercise itself never changes; only the headings do. Pre-made indexes:

| Index | Groups | Good for |
|---|---|---|
| **Muscle group** (default) | chest, back, shoulders, biceps, triceps, forearms, core, glutes, quads, hamstrings, calves | how most people think about training |
| **Body region** | upper, lower, core | a quick scan |
| **Equipment** | barbell, dumbbell, kettlebell, cable, machine, band, suspension, bodyweight | what can be done here |
| **Progression type** | by weight, by version | seeing which exercises have written levels |
| **Difficulty** | easy, medium, hard | what a hard day will push, what an easy day keeps at full |
| **Type** | strength, power, stability | what each one is for |

Muscle group is the index people expect, so it is the default. Exercises are tagged with twenty muscles by
their everyday names (chest; front, side and rear shoulders; biceps; triceps; forearms; abs; obliques; traps;
lats; upper back; lower back; glutes; outer hips; inner thighs; quads; hamstrings; calves; shins), the same
names the body map shows, and the eleven groups fold them: **shoulders** is all three heads; **back** is
lats, upper back and traps; **core** is abs, obliques and lower back; **glutes** includes the outer hips;
**quads** includes the inner thighs; **calves** includes the shins. An exercise sits under its first primary muscle, so nothing appears
twice; the card and the search also know every group it works.

A user-made index, picking any grouping of their own, is possible later: an index is a name plus a function
from exercise to group, and the data for all five above already exists on every exercise.

## What the app remembers per exercise

- **Working level.** The level, the working set count, and the rep range; where the level started (decay
  never goes below that).
- **Streaks.** Hits in a row (every working set at the top) and misses in a row (a set short of the floor),
  feeding the step-up and step-down rules in `APPLICATION.md` section 8. A light day touches neither.
- **Reps override.** A rep range for this exercise regardless of the goal's list, if the user set it.
- **Last time.** The last prescription and outcome, so Today can say "last time: three sets at 60 kg, all
  hit."
- **Best total** at the current level, which becomes the target at the top of a progression with no
  loading gear.
- **Seconds per set,** learned from set taps, used to make the minutes real.
- **Cost in play.** The default or override, nudged up when the exercise goes unpractised and down when its
  top is cleared repeatedly.
- **Workouts done, and when it was last done,** for decay and for preferring practised exercises.
- **The preference word,** and how many times in a row it has been swapped out without being done, for the
  "still like it?" line (`SELECTION.md`).

## Where it shows

- **In a workout:** name, level, the how-to for that level, target reps, the difficulty as a word. Swapping to another
  exercise for the same muscle, and editing today's level, happen from the row.
- **The exercise card:** level, seconds per set, best total, workouts done; the how-to at the current level;
  the progression as a track with every level, tap to make one yours; muscles worked; cost with its
  override; the preference word.
- **The catalog:** every exercise with levels (strength, power, stability) grouped by the chosen index, with its level and cost, searchable, filtered
  by what is available here, practised, bodyweight or weights. The index picker sits at the top.
- **Progress:** the level trend per exercise over the last thirty days, grouped the same way.

## How it fits the rest

Selection (`SELECTION.md`) asks the library for strength exercises that work a chosen muscle and fit the location's
equipment, and ranks them by readiness (`MUSCLE_MAP.md`), preference and practice; energy turns the dials on each; the
difficulty and the goal pick the expression and so the reps; the progression decides the level; the timing
model prices the sets in minutes. The index is for the user's eyes only: it never changes what the builder picks. Nothing here changes a
level except the progression rules and the user's own edit. Movement days (cardio and stretching) have no levels:
they are the library's cardio choices and stretching routines, described in `APPLICATION.md` section 7.

## What it never does

- Show a grouping the user did not pick.
- Call an exercise main or accessory. Cost and emphasis do that work.
- Change a level because of the day, the location, or the calendar.
- Lose a level when an exercise is swapped or unavailable somewhere.
- Let the index change the workout. Grouping is browsing, not building.

## Settings

| Setting | Default | Where |
|---|---|---|
| Index | muscle group | the catalog, Settings → Exercises |
| Difficulty, per exercise | library default | the exercise card |
| Reps, per exercise | the program's | the exercise card |
| Preference, per exercise | unrated | the exercise card, the swap sheet, after a workout |
| Level, per exercise | from experience, then earned | the exercise card or a workout row |
| Step up and step down workouts, decay weeks | 1, 2, 3 | Settings → Progressions |

## Open questions

- Half levels, step guides, user-made exercises and indexes, sharing: all in `IDEAS.md`.
