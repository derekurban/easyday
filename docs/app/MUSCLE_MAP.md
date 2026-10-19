# Muscle map

The muscle map is the app's one view of the body: the muscles by the names people use, and strain points, how much
work each muscle has taken and how much of it is still there. Anything that asks about a muscle asks the muscle
map: the figure on Today and Progress, the strain points timeline, and selection when it asks which muscles are ready. It never touches a level, a
working set, or a verdict.

## The muscles

Twenty, named the way people say them: chest; front, side and rear shoulders; biceps, triceps, forearms; abs and
obliques; traps, lats, upper back, lower back; glutes, outer hips, inner thighs, quads, hamstrings, calves; and the
shins, which are on the figure but no exercise works. Every exercise is tagged with its primary muscles, the ones
taking the load, and its secondary muscles, the ones helping. The eleven muscle groups of the index in
`EXERCISES.md` fold these names for browsing; the muscle map, selection and its ledgers always work by muscle.

## Strain points

One measure, from 0.00 to 1.00 per muscle, always written with two decimals. Every term below is a kind of strain
points, so there is one word for the whole mechanism.

- **Strain points from set.** A working set gives 0.20 to each primary muscle of its exercise and 0.10 to each
  secondary one. A light set gives half of that.
- **Strain points from exercise.** Its sets added up, under the same two limits as a workout.
- **Strain points from workout.** Its sets added up per muscle, with two limits: secondary work tops out at 0.50 in
  one workout, and a muscle tops out at 1.00. Five working sets fill a muscle for the day. Bench and flies is a
  chest day at 1.00, not more, and the triceps helping on every press stop at 0.50. **Planned** counts every set
  on the plan; **done** counts the sets attempted.
- **Current strain points.** What each muscle carries now: every workout's strain points, decayed, added together
  and capped at 1.00.
- **Strain point decay.** A third of a point comes off at the start of each day, by calendar days like the rest of
  the app, so a muscle drops exactly one shade a day. A workout adds to what is left, still capped at 1.00.
- **Strain-free.** A muscle at 0.00.
- **Strain points timeline.** Current strain points at the end of each day, with the workouts of each day
  marked.

| Strain points from workout | The day after | Two days after | Strain-free |
|---|---|---|---|
| 1.00 (chest day: five sets or more) | 0.67 | 0.33 | the third day |
| 0.60 (one exercise, three sets) | 0.27 | 0.00 | the second day |
| 0.30 (helping, or three light sets) | 0.00 | | the next day |

Two chest days in a row: Monday leaves 0.67 on Tuesday, Tuesday's workout takes it back to 1.00, and the three
days start again from Tuesday.

Strain points are never stored. They are worked out from the logged sets every time, so the figure, the timeline
and the builder can never disagree, and a change to the numbers re-reads the whole history the same way.

## The three shades

| Shade | Strain points |
|---|---|
| Low | 0.01 to 0.33 |
| Medium | 0.34 to 0.66 |
| High | 0.67 to 1.00 |

The shades are exact thirds and the decay is a third a day, so the shade is also how many days a muscle needs to be
strain-free, and every day it visibly steps down one shade. Strain is red: the design system's danger red (#AF3E30)
laid over the figure's plates at a third, two thirds and full strength, the same in both themes because the figure
is the same gray in both. A tapped muscle fills blue instead, as before. The strips on Progress and the timeline use
the same three shades.

## What it reads

- The sets of each lifting workout, planned or attempted, and whether each exercise was light.
- The primary and secondary muscles of each exercise.
- When each workout ended, for the day it counts on.

## What it changes

Which muscles are ready, and nothing else. Selection (`SELECTION.md`) asks two things of it:

- **Is a muscle ready.** A muscle is ready when it is strain-free. A muscle carrying strain waits, however far
  behind its share it is. Only the user's own pick of a muscle overrides this, and the plan says so.
- **How strained a candidate's muscles are with today's plan so far.** Once an exercise is on the plan, its
  strain points from workout are added before the next is chosen, so the next exercise goes to a fresh muscle
  rather than one the plan has already worked. Among ready candidates the lowest shade comes first.

Shuffle and the swap sheet read the same two answers. Which muscle is behind, which exercise is preferred, and
how much a workout holds are not the muscle map's to decide.

## Where it shows

- **Today:** the strain muscle map of the planned workout, its strain points from workout planned. A tap tells a
  muscle's strain points from this workout and what it carries now. The lines beside it say what the workout works and
  what is still carrying strain.
- **Progress:** the strain muscle map of current strain points, a line on what is strained and what is strain-free,
  and for each muscle a fourteen-day strip of its strain points at the end of each day, with when it was last
  worked.
- **The strain points timeline:** from Progress. The figure for one day, the last thirty days to pick from with
  workout days marked, a slider and a step back and forward. A tap tells a muscle's strain points that day; under the
  figure, that day's workouts and what each added.

## The interface

`lib/logic/muscle_map.dart`. `StrainPoints` holds strain points per muscle, with its shade, adding (capped) and
decay. `MuscleMap` is built on the state and answers everything else: strain points from set, from exercise and from
workout, current strain points at any moment, the strain points timeline between two days, the day a muscle will be
strain-free, and when each muscle was last worked. The figure takes strain points and draws their shades.

## What it never does

- Read energy, a weight, reps against the range, or the feel tap. The one thing intent changes is that a light set
  gives half, because it is less work on the muscle.
- Change a level, a working set count, the time fit, or how a workout is judged. The easy day's two working turns
  still go to the exercises that have waited longest.
- Add a set to chase a muscle, or let one muscle pass 1.00.
- Choose a muscle for being behind, or an exercise for being liked. Those are selection's to decide.

## How it fits the rest

Selection (`SELECTION.md`) decides which muscles and which exercises; the builder (`WORKOUT.md`) decides how many
exercises and sets there are and at what level; the muscle map says which muscles are ready. The muscle index (`EXERCISES.md`) folds the muscles into groups for browsing.
Progression (`APPLICATION.md` section 8) never hears from it.

## Settings

All fixed for now.

| Setting | Value |
|---|---|
| Strain points from a working set | 0.20 primary, 0.10 secondary |
| A light set | half |
| Secondary work in one workout | up to 0.50 |
| A muscle | up to 1.00 |
| Strain point decay | a third a day |
| Timeline | the last thirty days |

## Open questions

- Whether a set at the next level on a hard day should give more than a working set.
- Whether cardio should give the legs a little.
- Whether big muscles and heavy compounds should decay slower than small ones (`IDEAS.md`).
