# Workout

A workout fills the minutes the user has with the exercises selection chose (`SELECTION.md`), then turns
three dials on each exercise to match the energy they picked. Time is the hard edge. Energy never changes which exercises are
in the workout, only how hard each is asked. Cardio and stretching take the shares the user set, and spare
minutes go where the user said. There is no main lift, no accessory, and nothing a user has to understand
about the engine to set it up.

## What it is

- **Time is filled, always.** Every set has a price in seconds. The builder fits the chosen exercises by the
  goal's three calibrations (below), then spends what is left as the goal says: more exercises, cardio, or
  rest.
- **Three calibrations, not three caps.** The exercises in a workout, the working sets, and the exercises
  pushed on a hard day are each a band of three numbers: the fewest, the ideal, the most. The ideal is the
  sweet spot. A tight day falls toward the fewest and never below it unless the minutes cannot hold even
  that. A long day, one where the ideal list fills no more than half the window, or a hard day, grows toward
  the most. Nothing else ever reaches the most.
- **A level is a weight you can name.** A loaded exercise's level is its working weight in its home reps,
  and one level is one plate step: 155 lb, 160, 165, never a weight skipped. A bodyweight exercise's level
  is a version. A day with other reps chooses another **expression** of the same level, and the weight is
  carried to it (below).
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

| Expression | Reps | Weight, as a share of a max | Rest after a set |
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
weight share follows the range from the same table, so a custom range lands at a sensible weight.

**The home reps.** A loaded exercise keeps its level in its home reps: the range set on its card, else the
first range the goal tags its difficulty with. There the level is the weight on the bar, and a level is
exactly one plate step (2.5 kg on a bar, 2 kg on dumbbells; 5 lb, or 10 lb where the step is 5 kg or more).
Another range, the B workout of Mixed, carries the level by the table above, rounded to a plate step, and
is shown as that day's weight beside the level; a lighter range can round two levels to the same weight. A
changed goal, card range or unit lays the levels again around the current one: the level number stays and
its weight is carried to the new reps, so the weight the user lifts barely moves. Hitting the top of the
range raises the level by one step in any expression. For bodyweight, the version is the weight: the light
expression is one version down for more reps.

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
| Free form | moving between exercises is rest; no planned rest |

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

- **More exercises** (default): one more exercise at a time, dropped ones first, then the next muscle
  behind among those ready (`SELECTION.md`), at the day's intent. Anything still left is cardio.
- **Cardio**: all of it to the cardio block.
- **Rest**: nothing is added. The workout says "12 minutes to spare, no rush."

The feel tap tunes it: two "too much" taps in the last four workouts flip "more exercises" to cardio; two
"easy" taps flip cardio back. The tap is now asked only after a cardio or stretching day; a strength workout
ends on the finish screen, which does not ask it (an open question below). Nothing is ever asked per set.

## Cardio and stretching

Two sliders in Settings → Goal, each a share of every workout's minutes.

| Slider | Default | Range | What it does |
|---|---|---|---|
| Cardio | 15 % | 0 to 50 % | reserved at the end of every workout, after the strength exercises; also takes any slack they leave |
| Stretching | 10 % | 0 to 30 % | reserved last, after cardio; one of the fixed stretching routines sized to the minutes |

A 60-minute workout at the defaults is 45 minutes of lifting, 9 of cardio and 6 of stretching. Cardio is a single
duration with the effort tap at the end, as in a movement workout. Stretching has no tap. At zero a block
disappears, and with both at zero any slack is rest and the workout says "no rush." Neither gives strain points
for now. Movement workouts, a whole workout of cardio or stretching, stay as they are: the alternative to strength,
one tap away.

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
2. **Pick the muscles, then an exercise for each,** as `SELECTION.md` says: ready muscles furthest behind
   whose turn it is, most overdue first, and for each the exercise the location allows that is ready, preferred and
   practised. Energy plays no part.
3. **Assign intents** by the recipe. Each gets its expression, its sets and its target.
4. **Fit the minutes at normal.** The ideal sets everywhere. Over: exercises go down to the fewest, light
   ones first, then the last on the list; then sets come down to the fewest, the exercise with the most sets
   first; only when even that does not fit, below the fewest. Exercises dropped here come back first if room
   appears. A day that had to cut is tight; one where the ideal list fills no more than half the window is
   long.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest. More exercises grows the
   list back to the ideal; on a long day or a hard day it then grows sets toward the most, round the list
   one set at a time, then exercises toward the most. Then turn the dials for the energy picked, on that
   list. Easy never grows past the ideal.
6. **Cardio and stretching close it.** Stretching takes its share last; cardio takes its share before
   that, plus any slack the lifting left when spare minutes are not rest.
7. **Order** muscles marked more often first, then hardest first, while the user is fresh; at the same difficulty,
   extra and working before light. Strength lands on what goes first, so what the user cares about leads.

On the plan the user can reshuffle, swap any exercise for another for the same muscle available here,
edit today's level, or move an exercise up or down; their order then stands for today. Levels follow the
exercise, so none of that costs progress. A swap is repriced in minutes; if it no longer fits, one line
says what moved.

## A worked example

45 minutes at a commercial gym, five exercises for quads, chest, lats, abs and biceps, 40-minute window.

| Energy | The same five exercises | Sets | Expression on the squat | Shown as |
|---|---|---|---|---|
| Easy | squat light, bench light, plank working, curl working; pull-ups held back for time | 3 each | heavy, 4 to 7, at 85 % of the usual weight | about 60 % of your usual |
| Normal | all working | 3 each | heavy, 4 to 7, at your level | your usual |
| Hard | squat and bench at the next level, the rest working | 3 each | heavy, 4 to 7, one plate step up | the next level on squat and bench |

Same squat, same bench, same pull-ups at every energy. Easy is the same strength expressed lighter with a
set fewer; hard is one more set on the squat. In a tighter window the extra set goes before any exercise
does.

## Judging, afterwards

Each exercise is judged by one score against its working level and nothing else (`mobile/lib/logic/score.dart`).

**The score.** Every set is worth its load times one plus reps over thirty (Epley). The load is the weight, or for a
bodyweight version the share of bodyweight it moves: measured for the push-up versions (knee 0.49, floor 0.64, feet
elevated 0.74), otherwise each version taken as 1.2 times the one before. The exercise's score is the average of its
sets, each at the weight or version it was actually done at, so a weight changed mid-workout is read set by set.

Two bars come from the level and the rep range:

- **The floor**: this level at the bottom of the range.
- **Step up**: the higher of this level at the top of the range and the next level at the bottom. For a loaded lift
  that is the top of the range; for bodyweight it can ask for more (knee to floor push-ups: 18 knee push-ups in a 6
  to 10 range).

Next time is one of three words, **Harder**, **Same** or **Easier**, decided in this order:

| Situation | Next time |
|---|---|
| At the top of what this place can do | Same; the target is beating the best total |
| The first time ever | Same: a first go is taken as the right level. Harder if the reps averaged over the top and are worth a level more (or three or more over the top), Easier only if two or more under the floor |
| Still calibrating without calibration sets (holds, older workouts), the reps averaged over the top | Harder now, to the level the reps are worth |
| Every set at the next level, the average at its floor or better (a hard day) | Harder now |
| The average at the step-up bar | Harder after the step-up number in a row (default one); at once when coming back after decay |
| The average under the floor, at the working level, on a day that counts | Easier after the step-down number in a row (default two) |
| Anything else | Same |

A day counts against a level only when it ended normally or out of time: never on an easy-energy day, a low-energy
read, a light exercise, or one that hurt. Harder and Easier move one step; a first time can pick further on its wheel.

**Calibrating.** A new exercise starts at a guess and finds the user's weight in its first workout, with calibration
sets (`mobile/lib/logic/calibrate.dart`). Its first set is as many good reps as they can, up to 20, at the guess: the
target row says "As many as you can, up to 20" and the picture's tagline "Until form breaks" (the rack lifts' how-to
already says to set the safeties). Under 20, that set found it: read with the one rep people leave in the tank, it
gives the weight for the middle of today's range (the rating reads the reps as logged, like every working set, which
stop short too, so a lift does not drop after it calibrates), the rest of the sets are working sets at it, and it is the user's
level from then on. At 20 the set said only "at least", so the next set is heavier, by what 20 implies and 15 % more
(a newcomer's at most a quarter more), and another calibration set; with nothing done, a fifth lighter. Three at most
in a workout; three at 20 start heavier next time and keep looking. On the finish screen the tile says what found it
("14 reps at 60 kg found it", "Your weight: 67.5 kg"), with no Right or Too light to answer, and calibration sets are
left out of how the day is read (going to failure on purpose is not fading). Checked on simulated lifters before it was
built: one workout calibrated 97 to 100 % of new exercises with one or two hard sets; the app's guess was safer to start
from than the person's own pick (returning lifters overestimate), a cap of 15 left strong lifters short, and five sets
to failure were no more accurate than two. Holds, and workouts logged before calibration sets, find the level the old
way: reps averaged over the top jump to the level they are worth (`impliedRung`), and the first workout in the range
or under it found it.

**The guess** (`ensureState` in `mobile/lib/logic/ladder.dart`). An exercise with a strength standard starts at the
heaviest level that rates no more than a start rating in the middle of the range, for this user's build, bodyweight
and age: 750 for someone new, 950 with some experience, 1150 experienced (`experienceStart`), low on purpose since
reps over the top jump at once. Once a lift for the same muscles has found its level, a new one starts 50 under their
average rating instead (`startRating`), and finds its own level from there. An exercise without a standard keeps the
library's starting weight for the experience, scaled by the most practised loaded lift for the same muscles. One
weight for everyone put a newcomer woman near the middle of the people she is ranked against on most lifts.
Exercises skipped, never started or changed to another level before starting are not judged. A first time sets the
starting point and does not count toward a step-up run. The user can change any word on the finish screen; what is
shown when they tap Done is what is saved.

## The finish screen

End goes straight to the finish (`mobile/lib/ui/logged.dart`): no stop question, no feel tap. Every exercise is one
tile in one frame: a round mark, its name, one plain line, and at the right next time as a weight chip: the level it
lands on, outlined when it stays, with an arrow in the step's colour when it moves. A tap on the chip (or the tile)
opens Next time as three pills, minus, equals and plus: icons, the picked one opened with its word (Easier, Same,
Harder), the same control as the take's (love it, it's fine, not for me; `ChoicePills`). A first time without
calibration sets keeps its question instead.

**A step up is an event.** When next time goes up (the app's level, or Harder picked: STEPPING UP), the tile's edge
sweeps round once in the win's colours, a wash of them swells and fades, the tile pops a little, sparks burst from the
mark and the new weight rolls up into the chip, with a firm haptic and a second tick as it lands (an earned level
arrives the same way, quietly). Going down is a short mist wash and a light tick. Found in the Playground's tile lab on
2026-11-04, against a heart in the corner, three bare marks and a swipe for the take, and arrows and hold-to-step-up
for next time.

**Colour** (`mobile/lib/ui/palette.dart`, chosen in the Playground's colour lab on 2026-11-04). The scheme is Ember and
dusk: your own push is ember, a level the app earned is a soft violet dusk, going easy is mist blue-grey, finding out is
sea-glass teal, hurt alone is red, and moss green stays you, your level and your progress. The finish takes colour at
its edges: no tile is filled; a win (a level earned, your push) and a first time wear a thin edge in their colours with
a coloured mark and label, every other tile is plain with a coloured mark; the badge and the confetti at the top carry
the celebration. Each tile carries one accent colour, besides next time's word. Tried and set aside: a filled sweep on
every win (a rainbow stack), one filled headline tile, and marks with no edges. Rank bars fill in the rank's colour,
blending toward the next rank's.

- **What happened, per exercise**, the first that fits: it hurt; the user went heavier mid-workout and made every set
  (YOUR PUSH, its edge, a flame) or did not (reached for it); a first time; a level earned (LEVELLED UP, its edge);
  eased off partway; better than last time (heavier, or more total reps at the same weight); past the top of the
  range; short; steady. The mark shows which, or an arrow when next time moves.
- **A first time** has its own tile: a fresh-coloured edge and label, a compass mark; calibrated, the weight it
  found ("Your weight: 67.5 kg"); otherwise "How was 40 kg?" with Right
  picked (Too light or Too heavy opens a wheel of levels for next time), and the user's take: a heart, a thumbs up
  and a thumbs down, the picked one opened with its word. Unrated reads as the thumbs up.
- **The tone** of the headline and badge comes from the most telling moment: a push or a level celebrates (confetti
  only then), more than last time is pleased, reaching for more or falling short encourages, a hard day is proud,
  out of time is brief, all new is curious, otherwise steady.
- **How it ended.** Finished means every set of every planned exercise was done; time only sizes the plan. Finished
  with the sets fading 15 % or more on average reads as a low-energy day, silently. Anything left undone shows one
  tile, You finished early: Out of time, Low energy or No reason, the app's guess picked (time when 70 % of the
  minutes were used, energy when an exercise faded or fell under its floor, nothing when both or neither fit). No
  consequence is shown. Out of time makes the minutes the user had the default; low energy steps nothing down and
  two make easy the default; no reason changes nothing.
- **Check or fix details** opens the table of what was done (each set's reps, weight, time and rest), each line
  opening a drawer to correct it; the total time is the sum of the rows. Something hurt and Back to the workout are
  there too.

- **Strength rating.** Under each tile's line: the exercise's rank badge, its rating and how today moved it ("first
  rating" the first time, "new rank" with a small pop when it climbs a rank). See the strength rating below.

The page's layout is fixed when it opens, so a choice animates inside its own tile and nothing else moves. Debug
builds (the dev loops, never a release) have a Playground tab that opens the finish on sample workouts, the strength
rating on sample lifts, and under Ranks and calibration the real app over made-up lifters in every state (a calibration
set, past the cap, found; a first rank, still finding, a good day; Today and Progress unranked, provisional and
ranked), without touching the user's data.

## Strength rating

One number per exercise that rises with strength, whatever mix of weight, version and reps got there, and a rank from
it (`mobile/lib/logic/rating.dart`). Like a chess rating it places the user among people: three parts people who
train to one part everyone (`everyoneWeight`), so the measured standards do most of the ranking and a newcomer is
still not put off.

- **The crowd.** People who train come from the strength standards in `data/standards/` (built by
  `mobile/tool/gen_standards.py`; its README has the full table): five tiers, the strength that beats 5, 20, 50, 80
  and 95 % of people who train the lift, for men and women at bodyweights 10 kg apart. Each exercise combines every page
  that measures it: strengthlevel.com and Symmetric Strength (lifts people logged) count fully, FitnessVolt's model
  tables a half or a quarter. The spread runs through all five tiers. Everyone else is a normal spread centred at the
  lifters' 5 % mark, where studies of untrained adults put them (push-ups higher: most adults can do some). Standards
  are for ages 20 to 39 and scaled by the masters age coefficients outside them, which the standards' own age tables
  match. Build, birthday and bodyweight come from Settings, Your body; each workout is rated at the age the user was
  that day.
- **The scale.** 1200 is the middle of the crowd and 350 points one standard deviation, so the share of people beaten
  is exact. Ranks are 200-point bands: Iron under 800, Bronze, Silver from 1000, Gold from 1200, Platinum, Diamond,
  Champion from 1800.
- **A workout's worth** is the judging's score (load x (1 + reps/30), averaged over the sets). Bodyweight exercises
  are in their version's share of bodyweight x (1 + reps/30), so a standard counted in reps of one version rates every
  version; the assisted machine is read as pull-ups with the assist off bodyweight. What a standard stands on is named:
  measured, modelled (FitnessVolt only), a close cousin's page, or estimated (no page: from the beginner start, spaced
  like the measured lifts for the same muscles).
- **It moves like Elo**, from the day's best set (later sets are tired, and the standards are people's best efforts;
  rating from the average read every lift about 40 low). An exercise is in one of three stages (`LiftStage`).
  Calibrating: its weight is still being found, and a workout can only lift its rating, a floor. Calibrated: the
  workout that found it sets the rating outright, so a strong lifter starts high. Settled: one more workout at that
  weight; from then each workout moves it half the way to its worth for the next three, a quarter after. An easy or
  low-energy day, a light exercise, one that hurt, or a workout with every set at the top of the range (the user
  stopped where they were asked to) can lift it but never lower it, and cannot find its level. It is
  worked out from the logged workouts every time, never stored.
- **The overall rating** is the average rating of the lifts the user is training (done in the last six weeks; the
  measured ones, when any are; `overallHistory`). Unranked until two lifts are calibrated, usually after the first
  workout; provisional (the calibrated lifts) until five have settled; then the settled ones. A lift tried once never
  settles and never counts, one dropped leaves after six weeks. It moves as fast as the average lift really does: a
  good day moves it a few points while each lift moves more, so Today and the finish screen carry the day in the
  lifts. A workout's change is its lifts' movement over every lift counted; a lift joining is not a change. Progress
  draws the line from the lifts counted now (`overallLine`): each at its rating then, or its first rating before it
  had one, so a weaker lift settling later does not read as a drop, the line ends at today's number, and it runs back
  before the first rank. Tried and dropped: an average over every lift ever done (an old lift held it down for good),
  weights fading with time (a good day on a weak lift brought it back at full weight and lowered it), and the user as
  the player, moved by the average change of the day's lifts (each lift comes back about every five workouts, so it
  counted the same progress five times over).

The exercise card shows it under Strength: the rank and rating, the share of people it beats, what it is worth as
lifts, the rating over time, and what the next rank takes. The playground's strength lab tries it on sample lifts.

## Modes

One at a time, circuit or free form, chosen on the plan (the default is a setting) and changeable from the
chip at the top of the workout; it changes the order and the time pricing, nothing else.
One at a time puts each exercise on the strip as its own item. A circuit is one item: one set of each
exercise, round by round, with moving between them counted as rest and a planned ninety seconds between
rounds. Its time is shared out among its exercises by sets. Free form is one item too: after each rest,
I'm ready lists the exercises with a set left and the user taps the one to do next; an exercise whose sets
are all done drops off the list. Free form has no planned rest.

Changing the order mid-workout keeps what is done: the sets already logged stay where they were, and the rest
follow the new order. Back to one at a time, the finished exercises come first, then the one under way.

The level of the exercise under way can change mid-set from its target row: the weight (in plate steps) or
the version, in a drawer. It holds for that set and the ones after it, each set records the level it was
done at, and the planned level is kept for judging.

## What it never does

- Label an exercise main or accessory, or let a label decide what is trimmed.
- Let energy pick, swap, add or drop an exercise. Energy only turns the dials.
- Show an exercise's difficulty class as if it were how hard today is. Today is always shown against the
  user's usual.
- Let intent change a verdict, or a verdict change an intent.
- Show a number the user has to understand the engine to set.
- Ask for effort per set.

## How it fits the rest

The goal (`APPLICATION.md` section 6) writes the counts, the working set count and the reps-by-cost table.
Selection picks the muscles and the exercises (`SELECTION.md`), reading readiness from the muscle map
(`MUSCLE_MAP.md`) and what is available from the location (`LOCATION.md`). Exercises carry cost, levels and
how-to (`EXERCISES.md`). The calendar can lower the two picks on a busy day (`CALENDAR.md`).

## Settings

| Setting | Default | Where |
|---|---|---|
| Movement days | from the goal template | Settings → Goal |
| Working sets: fewest, ideal, most | 2, 3, 4 | Settings → Goal, 1 to 6 |
| Rep ranges, each tagged by difficulty | filled from a program: Strength, Build, Endurance, Mixed; up to six, those sharing a tag cycle by workout | Settings → Goal |
| Reps, per exercise | the goal's range for its difficulty | the exercise card |
| Different exercises: fewest, ideal, most | 2, 4, 6 | Settings → Goal, 1 to 10 |
| Hard day, next level on: tight, usual, long | 1, 2, 3 | Settings → Goal, 0 to 10 |
| Spare minutes go to | more exercises | Settings → Goal: more exercises, cardio, rest |
| Difficulty, per exercise | library default | the exercise card: easy, medium, hard |
| Cardio and stretching, share of every workout | 15 % / 10 % | Settings → Goal |
| Mode | straight sets | the plan, before starting |
| Warm-up block | 5 minutes | the plan: none, 3, 5, 8; kept for next time |
| A time limit, or a number of exercises | the minutes | Today, a switch; kept |
| When the planned rest runs out | keep resting | Settings → Workout: keep resting, start the next set |
| Show set time and rest as | minutes | Settings → Workout: minutes, share of time |
| After each step, the next button | waits a moment (3 s) | Settings → Workout: waits a moment, is ready at once |

## Open questions

- Spare minutes learned from the feel tap, which strength workouts no longer ask. Whether a low-energy read or a
  fade on the finish should tune it instead.
- Whether the light expression should also be used by the time fit on normal days, picking lighter reps on
  the small exercises when the window is tight, within what the goal allows.
