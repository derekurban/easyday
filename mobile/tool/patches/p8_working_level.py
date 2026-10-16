import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

A = r'D:\Working\fitness\docs\app\APPLICATION.md'
patch(A, [
# vocabulary
("""- **Energy.** How much the user has to give today: easy, normal, or hard. Sets the fatigue budget of the
  workout, the sum of its set costs, and how close to the limit sets are pushed.
- **Time.** How many minutes the user has today, on a slider. Sets the minutes budget, priced by the
  timing model. Energy and time are the two budgets a workout is built inside.""",
 """- **Energy.** How much the user has to give today: easy, normal, or hard. Sets the effort budget of the
  workout and the recipe of intents that spends it.
- **Time.** How many minutes the user has today, on a slider. Always filled: sets priced by the timing
  model, then cardio or rest for the remainder.
- **Working level.** Per exercise: the level, the working set count, and the rep range. What progression
  judges against. See section 8.2.
- **Intent.** What a workout asks of one exercise today: light (one level down, two sets), working (the
  working level), or extra (the working level plus a set). A prescription, never a judgement.
- **Effort.** Cost times sets times the intent's factor, summed over the workout. Energy is a budget of it.
- **Coverage.** Which muscle groups recent sets have worked, against what the goal wants. Chooses
  between candidate exercises; never touches a level. See `COVERAGE.md`."""),
# section 7
("""A workout is what fits inside two budgets. Energy gives a fatigue budget: the sum of the costs of every
set. Time gives a minutes budget: the sum of the learned seconds of every set. The builder spends both,
in the order the goal says, and stops when either runs out. The full procedure is in `WORKOUT.md`; the
shape is:

1. **Take the next rotation item.** A list of patterns in priority order. The first get sets first and
   lose them last. There is no main and no accessory.
2. **Pick an exercise for each pattern** from what the location has. Easy takes the cheapest practised
   exercise at cost 3 or under; normal the usual one; hard the costliest practised one. Hard never
   introduces an exercise the user has not practised.
3. **Start every exercise at two sets, then trim or grow.** Over either budget: drop the last exercise on
   the list first, down to a floor of two. Under both: add one set at a time to the first exercise that can
   take one, round and round, up to a cap; then add the next uncovered pattern; then minutes left with no
   fatigue left become an easy cardio block. More minutes always mean at least as many sets.
4. **Order it costliest first,** while the user is fresh.

Energy also sets the level and the reserve. Easy sits one level below the user's level, stops two or three
reps shy of the top, and is never judged. Normal and hard use the user's level and aim for the top; hard
holds nothing back. Levels are never changed by energy.""",
 """A workout fills the minutes, then balances the effort of what is in it to the energy pick. The full
procedure, with the numbers, is in `WORKOUT.md`; the shape is:

1. **Take the next rotation item.** A list of patterns in order. There is no main and no accessory.
2. **Pick an exercise for each pattern** from what the location has. Where several fit, coverage chooses
   the one whose muscle group is furthest behind (`COVERAGE.md`). On easy, nothing above cost 3. Hard never
   introduces an exercise the user has not practised.
3. **Give each exercise an intent** from the energy recipe: easy is light everywhere with up to two at
   working; normal is working wherever the budget allows; hard is extra on the costliest, working on the
   rest, light past the budget. Which exercises get the working turns: the ones that have waited longest.
4. **Price it and fit it.** Sets are priced in seconds by the timing model and in effort by cost times
   sets times the intent's factor. Over the budget: downgrade from the end. Over time: trim light sets,
   then drop the last exercise. Under both: add sets front to back, then one more pattern by coverage.
5. **Cardio fills the rest,** or rest does, by the cardio setting. More minutes always mean at least as
   many sets.
6. **Order it** extra and working first, light last, costliest first within each.

Energy never changes a level and never changes how an exercise is judged. It only decides which intent
each exercise gets today."""),
# 8.1
("""- **Hit the top.** The set reached the top of the rep range. One tap.
- **Below the top.** The set reached fewer reps. The number is logged, one more tap. This is the only
  thing that can hold or lower a level, and only in a normal or hard workout.
- **Not attempted.** The set never started. This happens when time trimmed it, when the workout was easy,
  or when the user stopped early. Never attempted sets are never failures.""",
 """- **Hit the top.** The set reached the top of the rep range. One tap.
- **In range.** The set reached the floor but not the top. The number is logged, one more tap. Holds the
  level: not ready to go up, no reason to go down.
- **Short.** The set did not reach the floor. The number is logged. The only outcome that can lower a
  level, and only at the working level.
- **Not attempted.** The set never started. This happens when time trimmed it, when the intent was light,
  or when the user stopped early. Never attempted sets are never failures."""),
("""- **Out of energy.** Nudges the energy default toward easy. Never a progression signal.""",
 """- **Out of energy.** Nudges the energy default toward easy. The one exercise it cut mid-way at the working
  level is a miss; everything after it is not attempted."""),
# 8.2
("""Each exercise has a rep range from the goal and a level. The target is always the same shape: this level,
this many sets, aim for the top of the range. The user does not manage reps. They lift, and the progression
reads the result.

- **Step up.** Every attempted set hit the top, for the step-up number of workouts in a row (default
  one): next time the level rises by one. Reps naturally fall back toward the bottom of the range.
- **Stay.** Anything short of that: the level stays and reps keep building.
- **Step down.** Any set below the bottom of the range, for the step-down number of workouts in a row
  (default two): the level drops by one.
- **Never judged.** Easy workouts, workouts stopped for energy or time, and sets never attempted. A
  "too much" feel tap also holds that workout.
- **Calibration.** The first time an exercise appears, a feel tap of easy with every set at the top steps
  up straight away, so a conservative starting level corrects in one workout.""",
 """Each exercise has a working level: its level, its working set count (from the goal, three by default),
and the rep range for its cost and the goal. The user does not manage reps. They lift, and the progression
reads the result against the working level, and against nothing else: not the energy pick, not the intent
the builder gave the exercise, not what else was in the workout.

- **Neutral.** The exercise was asked for less than its working level today: one level down, or fewer than
  the working sets. Nothing moves. A light day never breaks a streak.
- **Hit.** At the working level, every working set hit the top. Hit streak plus one. After the step-up
  number of hits in a row (default one), the level rises by one and reps fall back toward the floor.
- **Step up now.** A hit, and an extra set beyond the working sets also hit the top. Doing the working
  sets plus one, all at the top, shows the next level is already there; the count is skipped. If the extra
  set falls short, it is still a hit.
- **Hold.** At the working level, every set in range and none short. The hit streak resets; nothing else
  moves. Not ready to go up, no reason to go down.
- **Miss.** At the working level, any set short of the floor, or the working sets cut short by an energy
  stop. Miss streak plus one. After the step-down number of misses in a row (default two), the level drops
  by one. The floor is where the weight is wrong; the top is where it is earned.
- **Calibration.** The first time an exercise appears, a feel tap of easy with every set at the top steps
  up straight away, so a conservative starting level corrects in one workout.

Intent is how the builder asks; the working level is how the result is read. A user who picks easy for a
month keeps every level. A user who picks normal every day and does the work progresses everything."""),
# 8.3
("""Energy is the user's side of the same number. It is a fatigue budget, the sum of the costs of every set in
the workout: about 25 for easy, 40 for normal, 60 for hard. It also sets how close to the limit sets are
pushed, as written in section 7. Two workouts with identical reps and weights can be an easy day and a hard
day, depending on what is in them. That difference lives on the exercise, so it is explicit and editable.
The three budget numbers are settings and the only guesses in the model; the feel tap tunes them (below).""",
 """Energy is the user's side of the same number. It is an effort budget: cost times sets times the intent's
factor (light 0.6, working 1.0, extra 1.2), summed over the workout, about 20 for easy, 40 for normal, 60
for hard at forty minutes, growing with minutes up to an hour and flat past that. It also gives the recipe
of intents that spends it, as written in section 7. Two workouts with identical exercises can be an easy
day and a hard day, depending on the intents. The three budget numbers are settings and the only guesses
in the model; the feel tap tunes them (below)."""),
# 8.8
("""- **Energy and time are two budgets, spent together.** Neither can be overspent; a workout that does not fit
  is shorter, never heavier.""",
 """- **Time is filled, effort is budgeted.** A workout that does not fit the budget is lighter in intent,
  never shorter in minutes; a workout that does not fit the minutes is shorter, never heavier.
- **Intent in, working level out.** The builder prescribes; the progression reads the result against the
  working level and never asks what was prescribed."""),
# settings
("| Fatigue budget per energy level | 25 / 40 / 60 | easy 15 to 35, normal 30 to 55, hard 45 to 80 |",
 "| Working sets | 3 | 2 to 5 |\n| Effort budget per energy level | 20 / 40 / 60 | easy 10 to 35, normal 30 to 55, hard 45 to 80 |\n| Cardio | filler | none, reserved minutes, filler |\n| Emphasis per muscle group | none | 50 % less to 50 % more |"),
# section 13 progress line
("- **Progress.** Workouts per month over time. Level trend per exercise, grouped by the chosen index. Days active this month.",
 "- **Progress.** Workouts per month over time. Level trend per exercise, grouped by the chosen index. Coverage by muscle group over the last rotation. Days active this month."),
# open questions
("""- **The budget numbers are guesses.** 25, 40 and 60 need real days; the feel tap should correct them, but
  how fast is untested. The cost drift rules need to be watched for exercises that drop too fast.""",
 """- **The budget numbers are guesses.** 20, 40 and 60 need real days; the feel tap should correct them, but
  how fast is untested. The cost drift rules need to be watched for exercises that drop too fast.
- **Working sets.** Fixed by the goal for now. Whether the count should rise on its own when a user keeps
  doing and hitting extra sets."""),
# feature notes
("""- `WORKOUT.md`: a workout as two budgets, fatigue and minutes, spent in the goal's priority order; reps by
  cost; how the budgets learn.""",
 """- `WORKOUT.md`: filling the minutes, intents and the effort budget, reps by cost, and judging against the
  working level.
- `COVERAGE.md`: which muscle groups recent sets have worked, the goal's emphasis, and how the gap chooses
  between exercises."""),
])

E = r'D:\Working\fitness\docs\app\EXERCISES.md'
patch(E, [
("""- **Level.** Where the user is on the progression, and where it started (decay never goes below that).
- **Streaks.** Workouts in a row at the top of the range, or below the bottom, feeding the step-up and
  step-down rules in `APPLICATION.md` section 8.""",
 """- **Working level.** The level, the working set count, and the rep range; where the level started (decay
  never goes below that).
- **Streaks.** Hits in a row (every working set at the top) and misses in a row (a set short of the floor),
  feeding the step-up and step-down rules in `APPLICATION.md` section 8. A light day touches neither.
- **Last time.** The last prescription and outcome, so Today can say "last time: three sets at 60 kg, all
  hit.\""""),
("""The workout builder (`WORKOUT.md`) works in movement patterns and asks the library for exercises that fit
the location's equipment; energy picks among them by cost and spends its fatigue budget in it; the cost
also picks the rep range; the progression decides the level; the timing model prices the sets in minutes.""",
 """The workout builder (`WORKOUT.md`) works in movement patterns and asks the library for exercises that fit
the location's equipment; coverage chooses among them (`COVERAGE.md`); energy spends its effort budget in
cost; the cost also picks the rep range; the progression decides the level; the timing model prices the
sets in minutes."""),
])

M = r'C:\Users\derek\.claude\projects\D--Working-fitness\memory\fitness-app-intent.md'
patch(M, [
("(energy = fatigue budget 25/40/60 of summed set costs; minutes = time budget, slider 10 to 120). NO main vs\naccessory (dropped 2026-10-15): the goal is a priority order of patterns, reps follow cost; see docs/app/WORKOUT.md.",
 "(energy = effort budget 20/40/60 at 40 min of cost x sets x intent factor, light 0.6 / working 1.0 / extra 1.2;\nminutes always filled, cardio as filler). NO main vs accessory (dropped 2026-10-15). Progression judges ONLY\nagainst the working level (level + working sets + range): light days neutral, in-range holds, short of floor\nmisses, working sets + an extra set all at top = step up now. Intent never affects judging. Muscle coverage\nchooses between candidate exercises (COVERAGE.md). See docs/app/WORKOUT.md."),
])
print('ok')
