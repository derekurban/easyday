# Muscle coverage

Coverage keeps a full-body plan honest. It counts which muscle groups the user's recent sets have worked,
compares that with what the goal wants, and uses the gap to choose exercises. It also carries the two
dials for what is not lifting: how much of every workout goes to cardio and how much to stretching. It
never touches a level, a working set, or a verdict; it only decides which exercise fills a slot and how
the end of the workout is spent.

## What it is

- **Credits.** Credits go to the muscles doing the work, by the twenty everyday names: every working or
  extra set credits each of its exercise's primary muscles one point and each secondary muscle half a point
  (a row: the upper back one, the lats, biceps and rear shoulders half each). Light sets credit half of
  that. Where coverage weighs groups (the eleven of the muscle index in `EXERCISES.md`), a group is read
  from its muscles.
- **A window.** The last rotation: as many workouts as the rotation is long, so a four-workout rotation
  looks back four workouts. Movement workouts are in the window but credit nothing.
- **A target share.** Even across the eleven groups by default, then tilted by the user's emphasis: "20 %
  more on back" multiplies back's share by 1.2 and the rest are scaled so the shares still sum to one.
- **A deficit.** Target share minus actual share, per group. Positive means behind.

## What it reads

- The sets of the workouts in the window, with the exercise each set belonged to.
- The muscle groups of each exercise.
- The emphasis settings in the goal.

## What it changes

- **Which exercise fills a pattern.** When the builder has more than one candidate for a pattern at this
  location, it takes the one whose primary group has the largest deficit; ties go to the practised one,
  then the goal's order. Pull becomes a row when the upper back is behind, a pulldown when lats are.
- **Which exercises do the work on an easy day.** Easy gives two exercises a working turn; they are the
  two whose primary groups have the largest deficit, among the easy and medium ones. An easy day is a
  catch-up day for whatever has been missed, without the hard lifts.
- **Which pattern gets an extra slot.** When spare minutes are for more exercises and there is room for one more
  exercise, the pattern that serves the group with the largest deficit is added, instead of the next on
  the goal's list.
- **Nothing else.** Levels, working sets, verdicts, the rotation order, and the energy recipe are not
  inputs or outputs here.

## Emphasis

One slider per muscle group in Settings → Goal, from 50 % less to 50 % more, default none. Most users touch
one or two. The row reads as a sentence: "Back: 20 % more." Emphasis changes the target share and nothing
else, so it shows up as more pull and hinge exercises chosen over time, not as a different rotation.

## Cardio and stretching

Two sliders beside the muscle ones, each a share of every workout's minutes.

| Slider | Default | Range | What it does |
|---|---|---|---|
| Cardio | 15 % | 0 to 50 % | reserved at the end of every workout, after the lifting; also takes any slack the lifting leaves |
| Stretching | 10 % | 0 to 30 % | reserved last, after cardio; one of the fixed mobility routines sized to the minutes |

A 60-minute workout at the defaults is 45 minutes of lifting, 9 of cardio and 6 of stretching. Cardio is a single duration with the effort tap at the end, as in a movement workout.
Stretching has no tap. At zero a block disappears, and with both at zero any slack is rest and the
workout says "no rush." Neither credits a muscle group for now. Movement workouts, a whole session of
cardio or mobility, stay as they are: the alternative to lifting, one tap away.

## Built so far

As of 0.13.4 the muscle side is shown, not yet used to choose. One component, `MuscleFigure`, draws the
rendered maps from `muscle-map/` (male or female, picked in Settings → Personalization; front and back). Muscles are named the way
people say them, twenty in all: chest; front, side and rear shoulders; biceps, triceps, forearms; abs and
obliques; traps, lats, upper back, lower back; glutes, outer hips, inner thighs, quads, hamstrings, calves;
and the shins, which no exercise works. Exercises are tagged with these names, the figure highlights by them
and a tap shows one as the title. Primary muscles fill with the design system's moss accent at full
strength, secondary ones at a lighter step, with a key under the figures. Tapping a plate fills every plate
of that muscle blue in place of its step, on both figures, and floats a tooltip over the render with its
name and a line from the screen: on Today which exercises use it as main or helper, on Progress when its
group was last worked. An expand button opens the figure full screen with pinch zoom, a Both / Front / Back
toggle and the same tap details in a panel. On Today it shows only the planned workout: the exercises'
primary and secondary muscles. On Progress it shows recency: each muscle tinted
by how worked it is, from the sets of the last five days faded by the days since,
one point per set on each primary muscle and half on each secondary, light sets half of that; a tap tells
when that muscle was last worked. Progress also shows a fourteen-day strip and "last worked" per muscle. The
credits, window and deficit that would choose exercises are not built; the builder still takes the usual
pick for a pattern.

## Where it shows

- **Progress:** a coverage view, the eleven groups as bars of actual against target over the last
  rotation, grouped the same way the muscle index groups the catalog.
- **Today:** when coverage changed a pick, one line under the exercise: "rows today, back is behind." Under
  the plan, the closing blocks: "then 9 min cardio, 6 min stretching."
- **Settings → Goal:** the emphasis sliders, and the cardio and stretching sliders beside them.

## What it never does

- Change a level, a working set count, or how a workout is judged.
- Add sets to chase a target. It chooses between exercises that would be there anyway.
- Count secondary muscles as primary work, or let a group's deficit grow without bound: a deficit is a
  share, so it tops out.

## How it fits the rest

The builder (`WORKOUT.md`) decides how many exercises and sets there are and at what level; coverage
decides which exercises. The muscle index (`EXERCISES.md`) gives the groups and their fold from the
library's muscle names. The goal owns the emphasis. Progression (`APPLICATION.md` section 8) never hears
from it.

## Settings

| Setting | Default | Range |
|---|---|---|
| Emphasis, per muscle group | none | 50 % less to 50 % more |
| Cardio, share of every workout | 15 % | 0 to 50 % |
| Stretching, share of every workout | 10 % | 0 to 30 % |
| Window | the last rotation | fixed for now |
| Secondary credit | half a point | fixed for now |

## Open questions

- How many workouts of history are enough before the deficit is trusted over the goal's order.
- The rest are in `IDEAS.md`: cardio crediting legs, stretching following coverage, a deficit adding a
  pattern, a time-based window.
