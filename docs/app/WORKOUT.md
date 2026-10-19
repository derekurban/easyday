# Workout

A workout fills the minutes the user has with the exercises the goal lists, then turns three dials on each
exercise to match the energy they picked. Time is the hard edge. Energy never changes which exercises are
in the workout, only how hard each is asked. Cardio and stretching take the shares the user set, and spare
minutes go where the user said. There is no main lift, no accessory, and nothing a user has to understand
about the engine to set it up.

## What it is

- **Time is filled, always.** Every set has a price in seconds. The builder fits the listed exercises by the
  goal's three calibrations (below), then spends what is left as the goal says: more exercises, cardio, or
  rest.
- **Three calibrations, not three caps.** The exercises in a workout, the working sets, and the exercises
  pushed on a hard day are each a band of three numbers: the fewest, the ideal, the most. The ideal is the
  sweet spot. A tight day falls toward the fewest and never below it unless the minutes cannot hold even
  that. A long day, one where the ideal list fills no more than half the window, or a hard day, grows toward
  the most. Nothing else ever reaches the most.
- **A level is strength, not a weight.** A loaded exercise's level is an estimated max; a bodyweight
  exercise's level is a version. The level never says how many reps. The workout chooses an
  **expression** of it, and the weight follows (below).
- **Energy is three dials, never a pick.** The list is built once, at normal, and fitted to the minutes.
  Energy then turns the dials on exactly that list: each exercise gets an intent for today, light,
  working or extra, and intent sets the expression, the sets and the reserve. Easy, normal and hard show
  the same exercises, added ones included; only the numbers beside them change.
- **Everything the user sees is relative to their usual.** The usual is the working level: their weight,
  their sets. A row shows today against that, "60 %", "usual" or "+1 set", with a three-bar meter, and
  the workout shows the same for the whole: "about 60 % of your usual", "your usual", "your usual, plus
  one extra set". An exercise's difficulty class (easy, medium, hard) is a property of the exercise, shown
  on its card and in the catalog, never as a measure of today.
- **Intent is a prescription, not a judgement.** The progression never hears which intent an exercise was
  given. It judges what happened against the exercise's working level.

## Difficulty

Every exercise is easy, medium or hard: how much one hard set takes out of the whole body. The word in a
small pill in the catalog and during a workout, on the card with its override, and an index in the catalog.
Never dots: a newcomer should not have to decode them. The library carries a
finer number underneath; the user never sees it.

## Expressions

| Expression | Reps | Weight, as a share of the level | Rest after a set |
|---|---|---|---|
| Heavy and few | 4 to 7 | about 85 % | 3 minutes |
| Middle | 8 to 12 | about 70 % | 90 seconds |
| Light and many | 13 to 18 | about 60 % | 60 seconds |

The goal holds a list of rep ranges, up to six, each tagged with the difficulties it applies to: hard,
medium, easy, any mix. That list is the whole program. The ranges tagged with a difficulty, in list order,
are what its exercises train in, and when there is more than one they cycle by workout, A, B, C. A
difficulty with no range of its own borrows the nearest one's. The named programs are suggestions that fill
the list: Strength is heavy tagged hard, middle tagged medium, light tagged easy; Build is middle tagged hard
and medium, light tagged easy; Endurance is one light range tagged all three; Mixed is Strength with the
middle range also tagged hard, so hard lifts alternate heavy and middle, A and C heavy, B and D middle. Any
range can be edited to any numbers and retagged in its sheet. Any exercise can be set to its own range on
its card, for the lifter who wants seven on the bench and many on the calves whatever the list says. The
weight share follows the range from the same table, so a custom range lands at a sensible weight. Hitting the top of the range in any expression
raises the level by one step, and every expression moves by at least one plate step per level, so progress
is always visible whichever reps the user likes. Changing the reps changes the weight, never the level.
For bodyweight, the version is the weight: the light expression is one version down for more reps.

Holds keep their own ranges in seconds. Bodyweight versions keep their floor, so a version is never asked
for fewer reps than make sense for it. Max estimates get loose past twelve reps, so the light expression
stops at 18 for loaded lifts.

## Time per set

Generous defaults, replaced by the user's own seconds per set once the timing model has a few workouts.
Each set is work plus rest plus transition, rounded up to the next 15 seconds.

| Part | Default |
|---|---|
| Work | 3 s per rep at the top of the range, or the hold seconds |
| Rest after | by expression, above |
| Transition | 15 s per set, plus 60 s per change of exercise |
| Warm-up sets | two, 60 s each, on loaded hard exercises; never logged |
| Warm-up block | 5 minutes before the first exercise, inside the minutes; none, 3, 5 or 8 on the plan |
| Circuit mode | moving between exercises is rest; 90 s planned between rounds |

An exercise's time is learned whole: from the moment its first set starts to the start of the next item, so
the rest between sets, the rest after the last one and setting up the next are all in it. A set is lifting
from I'm ready to the reps; everything else is rest. Neither is ever asked for; both come from the two taps
the workout needs anyway.

## The working level

Every exercise has a working level: its level, its working set count (the goal's ideal sets, three by
default), and the rep range of its expression. Sets stay inside that band for good; progress is the level
rising, never the sets. On a tight day the sets may fall toward the goal's fewest, and those sets still
count; on a long or hard day sets may grow toward the most, and only the usual ones are judged.

The range is a verdict, not a target. The instruction is always the same: as many as you can with good
form. Then the number says what it says: under the floor, the weight is too much; floor to just under the
top, fine, this is what training looks like; the top or more, ready for more. For 4 to 7: 3 says lower,
4 to 6 says fine, 7 or more says upgrade. "Hit" is the top or more, "in range" the floor to under the top,
"short" under the floor.

## Intents

| Intent | Expression | Level | Sets | Target |
|---|---|---|---|---|
| Light | the goal's | the user's, at 85 % of the usual weight; bodyweight: one version down | the working sets | the range, nothing judged |
| Working | the goal's | the user's | the working sets | as many as you can; the top or more is the signal to go up |
| Next level | the goal's | the next level, every set | the working sets | as many as you can; the floor on every set makes it yours today |

Light is "do something": the same reps at a lighter weight, full sets, nothing judged. A plate step is
the wrong unit for easy, so loaded exercises take a share of the usual weight (85 %, fixed for now,
tunable later per `IDEAS.md`); a version is a big enough step on its own, so bodyweight goes one version
down. An easy day is few exercises done properly, not many done thinly: it keeps full sets and holds about
two thirds of the lifting window, dropping the last light exercises on the list until it fits. Nobody is demoted for picking easy. Working is the proper work. Next level is the whole exercise one
step up, the next weight step or the next version, and is how a hard day gives the user something to work
toward: prove the next notch and it becomes the new normal. The expression never changes with energy.

## Energy

| | Recipe |
|---|---|
| Easy | light everywhere, fewer exercises at full sets; two exercises at working, easy and medium ones first, the longest-waiting among them |
| Normal | working everywhere |
| Hard | the next level on the hardest few, working on the rest; room to grow toward the most sets and exercises |

No budgets, no points. Easy and normal share one list; hard holds everything normal does and may add to
it. How many exercises a hard day pushes is the third calibration: the fewest on a tight day, the ideal on a
usual one, the most on a long one, hardest exercises first. A hard day takes the same minutes as a normal
one, one step heavier, so it always fits; with spare minutes set to more exercises it also grows toward the
most sets, then the most exercises, like a long day.

**Sanity caps,** never targets: hard exercises per workout, none on easy, one on normal, two on hard; sets
per muscle group counting primary only, 4 on easy, 6 on normal, 8 on hard.

## Spare minutes

Once the listed exercises fit, what is left goes where the goal says, in one plain setting:

- **More exercises** (default): one more pattern at a time, dropped ones first, then the rest of the
  rotation item, then the free patterns, at the day's intent. Anything still left is cardio.
- **Cardio**: all of it to the cardio block.
- **Rest**: nothing is added. The workout says "12 minutes to spare, no rush."

This is what the feel tap tunes. Two "too much" taps in the last four workouts flip "more exercises" to
cardio; two "easy" taps flip cardio back. Nothing is ever asked per set, and nothing the user sees is a
number they have to understand.

## A time limit, or a number of exercises

Time is the minutes by default. With the time limit switched off on Today, the user picks how many
exercises instead, between the goal's fewest and most and starting at its ideal, and the minutes follow:
the list is that many exercises at the ideal sets, the last on the list going first and the same growth
order as spare minutes adding more, and cardio and stretching keep their shares of the whole. There are no
spare minutes then, and an easy day keeps the count it was given. The switch is remembered.

## How it is built

1. **The window** is the minutes picked, minus the warm-up block and the cardio and stretching shares (a
   share left out on the plan for today is not taken). Loaded hard exercises also carry their own warm-up
   sets. With the time limit off the window is open and the count decides.
2. **Pick an exercise per pattern** in the rotation item, from what the location has. Where there is
   more than one candidate, coverage chooses (`COVERAGE.md`). Energy plays no part.
3. **Assign intents** by the recipe. Each gets its expression, its sets and its target.
4. **Fit the minutes at normal.** The ideal sets everywhere. Over: exercises go down to the fewest, light
   ones first, then the last on the list; then sets come down to the fewest, the exercise with the most sets
   first; only when even that does not fit, below the fewest. Patterns dropped here come back first if room
   appears. A day that had to cut is tight; one where the ideal list fills no more than half the window is
   long.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest. More exercises grows the
   list back to the ideal; on a long day or a hard day it then grows sets toward the most, round the list
   one set at a time, then exercises toward the most. Then turn the dials for the energy picked, on that
   list. Easy never grows past the ideal.
6. **Cardio and stretching close it.** Stretching takes its share last; cardio takes its share before
   that, plus any slack the lifting left when spare minutes are not rest.
7. **Order** hardest first, while the user is fresh; at the same difficulty, extra and working before
   light.

On the plan the user can reshuffle, swap any exercise for another of the same pattern available here,
edit today's level, or move an exercise up or down; their order then stands for today. Levels follow the
exercise, so none of that costs progress. A swap is repriced in minutes; if it no longer fits, one line
says what moved.

## A worked example

45 minutes at a commercial gym, a squat, push, pull, core, arms item, 40-minute window.

| Energy | The same five exercises | Sets | Expression on the squat | Shown as |
|---|---|---|---|---|
| Easy | squat light, bench light, plank working, curl working; pull-ups held back for time | 3 each | heavy, 4 to 7, at 85 % of the usual weight | about 60 % of your usual |
| Normal | all working | 3 each | heavy, 4 to 7, at your level | your usual |
| Hard | squat and bench at the next level, the rest working | 3 each | heavy, 4 to 7, one plate step up | the next level on squat and bench |

Same squat, same bench, same pull-ups at every energy. Easy is the same strength expressed lighter with a
set fewer; hard is one more set on the squat. In a tighter window the extra set goes before any exercise
does.

## Judging, afterwards

Each exercise is judged against its working level and nothing else.

| What was asked | What happened | Verdict |
|---|---|---|
| Below the working level (light) | anything | neutral: no streak moves |
| At the next level (a hard day) | every working set reached the floor | step up now: it is yours |
| At the next level, bodyweight | a set fell short of the floor | neutral: it was an attempt |
| At the next level, loaded | a set fell short | read by worth, below |
| At the working level | every working set at the top or more | hit: hit streak plus one |
| At the working level | every set in range, none short | hold: hit streak resets, nothing else |
| At the working level | any set short of the floor | miss: miss streak plus one |
| At the working level | cut short by an energy stop | miss |
| At the working level | cut short by time, pain, or no reason | neutral |

**Read by worth.** A loaded set is worth what it would be at the usual weight, by the same percent-of-max
table that defines the expressions (max is weight times one plus reps over thirty). So on a hard day a set
that fell one rep short at the next level is converted: seven at 72.5 kg is worth about nine at 70, which is
in range, so the exercise holds at the current level rather than being marked short. Below the floor's
worth is a miss; the top's worth or more is a hit. At the usual weight the worth is just the reps.

Step up after the step-up number of hits in a row (default one). Step down after the step-down number of
misses in a row (default two). A hard day is the one way to skip the count: the floor on every set at the
next level shows it is already yours. Only the exercise that was cut
mid-way by an energy stop is a miss; exercises never started are not attempted and neutral.

The feel tap tunes spare minutes and nothing else. The one line after the workout says what moved.

## Modes

Straight sets or circuit, chosen on the plan; it changes the order and the time pricing, nothing else.
Straight sets put each exercise on the strip as its own item. A circuit is one item: one set of each
exercise, round by round, with moving between them counted as rest and a planned ninety seconds between
rounds. Its time is shared out among its exercises by sets.

## What it never does

- Label an exercise main or accessory, or let a label decide what is trimmed.
- Let energy pick, swap, add or drop an exercise. Energy only turns the dials.
- Show an exercise's difficulty class as if it were how hard today is. Today is always shown against the
  user's usual.
- Let intent change a verdict, or a verdict change an intent.
- Show a number the user has to understand the engine to set.
- Ask for effort per set.

## How it fits the rest

The goal (`APPLICATION.md` section 6) writes the pattern list, the working set count and the reps-by-cost
table. Exercises carry cost, levels and how-to (`EXERCISES.md`). The location says what is available
(`LOCATION.md`). Coverage chooses between candidates (`COVERAGE.md`). The calendar can lower the two
picks on a busy day (`CALENDAR.md`).

## Settings

| Setting | Default | Where |
|---|---|---|
| What to cover, in order; movement days | from the goal template | Settings → Goal |
| Working sets: fewest, ideal, most | 2, 3, 4 | Settings → Goal, 1 to 6 |
| Rep ranges, each tagged by difficulty | filled from a program: Strength, Build, Endurance, Mixed; up to six, those sharing a tag cycle by workout | Settings → Goal |
| Reps, per exercise | the goal's range for its difficulty | the exercise card |
| Different exercises: fewest, ideal, most | 2, 4, 6 | Settings → Goal, 1 to 10 |
| Hard day, next level on: tight, usual, long | 1, 2, 3 | Settings → Goal, 0 to 10 |
| Spare minutes go to | more exercises | Settings → Goal: more exercises, cardio, rest |
| Difficulty, per exercise | library default | the exercise card: easy, medium, hard |
| Cardio and stretching, share of every workout | 15 % / 10 % | Settings → Goal, beside the emphasis sliders |
| Mode | straight sets | the plan, before starting |
| Warm-up block | 5 minutes | the plan: none, 3, 5, 8; kept for next time |
| A time limit, or a number of exercises | the minutes | Today, a switch; kept |
| When the planned rest runs out | keep resting | Settings → Workout: keep resting, start the next set |
| Show lifting and rest as | minutes | Settings → Workout: minutes, share of time |

## Open questions

- How many workouts of history coverage needs before easy's catch-up picks beat the goal's order. Two
  is the guess.
- Whether the light expression should also be used by the time fit on normal days, picking lighter reps on
  the small exercises when the window is tight, within what the goal allows.
