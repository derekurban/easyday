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
("""- **Goal.** What the plan is for, as rep ranges, how many main lifts and accessories a workout plans, and
  how often a movement day replaces a lifting day. Starts from a plain-language template such as "get
  stronger" or "build muscle"; every knob can be changed, and a changed template is a custom goal.
- **Movement pattern.** The building block of a plan: push, pull, hinge, squat, carry, core, plus
  accessory patterns (arms, shoulders, legs) and cardio and mobility blocks. Plans are written in patterns, not
  exercises.""",
 """- **Goal.** What the plan is for: what each workout covers, in priority order, which reps-by-cost table it
  uses, and how often a movement day replaces a lifting day. Starts from a plain-language template such as
  "get stronger" or "build muscle"; every knob can be changed, and a changed template is a custom goal.
- **Movement pattern.** The building block of a plan: squat, hinge, push, pull, carry, core, arms,
  shoulders, legs, plus cardio and mobility blocks. Plans are written in patterns, not exercises. There is
  no main or accessory pattern; there is an order."""),
("""- **Rep range.** The band of reps per set the goal asks for, such as 8 to 12. The target is always the
  top of the range at the current level.
- **Cost.** A number from 1 to 5 on each exercise for how much a hard set takes out of the whole body.
  Comes with a default, can be overridden, and drifts with practice and neglect.
- **Energy.** How much the user has to give today: easy, normal, or hard. Sets the average cost of the
  workout and how close to the limit sets are pushed.
- **Time.** How many minutes the user has today, on a slider. Sets how many sets and exercises fit,
  priced by the timing model.""",
 """- **Rep range.** The band of reps per set, such as 8 to 12. It follows the cost of the exercise and the
  goal, so heavy compounds get the low range and small movements the high one. The target is always the
  top of the range at the current level.
- **Cost.** A number from 1 to 5 on each exercise for how much one hard set takes out of the whole body.
  Derived from the exercise itself (section 8.3), can be overridden, and drifts with practice and neglect.
- **Energy.** How much the user has to give today: easy, normal, or hard. Sets the fatigue budget of the
  workout, the sum of its set costs, and how close to the limit sets are pushed.
- **Time.** How many minutes the user has today, on a slider. Sets the minutes budget, priced by the
  timing model. Energy and time are the two budgets a workout is built inside."""),
# core loop
("5. **Do the workout.** Loaded main lifts show two warm-up sets that are never logged.",
 "5. **Do the workout.** Loaded exercises at cost 4 or 5 show two warm-up sets that are never logged."),
# goal translation
("""- **Goal.** One pick from a short list of templates, each stating what it means in practice: the rep
  ranges, how many lifts a workout plans, and how often a movement day comes round.""",
 """- **Goal.** One pick from a short list of templates, each stating what it means in practice: what a
  workout covers and in what order, the reps-by-cost table, and how often a movement day comes round."""),
("""**Goal translation** maps the chosen goal to the rep range each pattern uses, which patterns are
emphasised, and how much of the rotation is movement workouts. Strength uses 4 to 6 on main lifts, muscle
8 to 12, fitness 12 to 20. Changing the goal retranslates the plan but keeps every level, so changing goals
never means starting over.""",
 """**Goal translation** maps the chosen goal to the order patterns are covered in, the reps-by-cost table,
and how much of the rotation is movement workouts. Strength trains cost 4 and 5 exercises at 4 to 6 reps,
cost 3 at 6 to 10, cost 1 and 2 at 10 to 15; muscle and fitness shift the same three bands up (the table
is in `WORKOUT.md`). Changing the goal retranslates the plan but keeps every level, so changing goals never
means starting over."""),
# section 7
("""A workout is built in three steps.

1. **Pick the next rotation item.** Each item is a list of patterns in order, main patterns first, with
   accessory patterns after.
2. **Size it by time.** The minutes decide how many sets and exercises there are. Every exercise starts
   with a base number of sets from the energy pick, and the timing model prices each one in seconds per
   set, so the plan fits the minutes the user said they have. Over budget: sets are trimmed before
   exercises, and accessories before mains. Under budget: sets are added to the main lifts first, up to a
   cap, then to accessories, then extra accessory exercises are added, and any minutes still left become
   an easy cardio block at the end. More minutes always mean at least as many sets.
3. **Fill it by energy.** For each pattern slot, the exercise library offers the variants available at the
   location, each with a cost. Energy picks among them.
   - **Easy.** Average cost at most 2 and nothing above 3. Every exercise sits one level below the user's
     level, sets stop two or three reps shy of the top, and one set fewer. Easy workouts are logged and
     counted, and never judged by the progression.
   - **Normal.** Average cost around 3, with at most one exercise at 4 or 5. The user's level, aiming for
     the top of the range.
   - **Hard.** At least half the slots at cost 4 or 5. The user's level, nothing in reserve, one extra set
     on the main lifts and a higher cap on them when there is time. When time is tight, accessories go
     before a main-lift set is cut. Hard never introduces an exercise the user has not practised.
   High-cost exercises come first while the user is fresh. Levels are never changed by energy.

The user can reshuffle the exercises of today's workout, or swap any one of them for another exercise of the
same pattern available at the location. Levels follow the exercise, so a swap never costs progress. Every exercise
carries a step guide of how to perform it, and the workout shows the muscles it will work.""",
 """A workout is what fits inside two budgets. Energy gives a fatigue budget: the sum of the costs of every
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
holds nothing back. Levels are never changed by energy.

The user can reshuffle the exercises of today's workout, or swap any one of them for another exercise of the
same pattern available at the location. Levels follow the exercise, so a swap never costs progress. A swap is
repriced against both budgets. Every exercise carries a how-to at its level, and the workout shows the muscle
groups it will work."""),
# 8.3
("""Every exercise has a cost from 1 to 5 for how much a hard set takes out of the whole body, not just the
muscle. Defaults: 5 for heavy compounds that load the spine such as deadlift and back squat; 4 for big
compounds such as bench press, pull-up and overhead press; 3 for bodyweight compounds such as pike push-ups
and lunges; 2 for machine compounds; 1 for isolation work. The user can override any exercise's cost in the
catalog.

Energy is the user's side of the same number. It decides the average cost of what fills the workout, the
ceiling on any single exercise, and how close to the limit sets are pushed, as written in section 7. Two
workouts with identical reps and weights can be an easy day and a hard day, depending on what is in them.
That difference lives on the exercise, so it is explicit and editable.""",
 """Every exercise has a cost from 1 to 5 for how much one hard set takes out of the whole body, not just the
muscle. The default is derived, not guessed, from three things anyone can check on the exercise:

- **How much muscle moves.** One small group alone (biceps, calves, forearms): 1. One big group, or an
  isolation of one (leg curl, chest fly, lateral raise): 2. Several groups at once: 3.
- **Plus one if the load goes through the spine or the whole body hangs from the arms:** squats,
  deadlifts, overhead presses, carries, pull-ups, dips.
- **Plus one if the load can get heavy relative to bodyweight:** a barbell or trap bar on a big compound.

So a deadlift is 5, a bench press 4, a pull-up 4, a pike push-up 3, a leg press 2, a curl 1. The user can
override any exercise's cost in the catalog, and the card shows which of the three it came from.

Energy is the user's side of the same number. It is a fatigue budget, the sum of the costs of every set in
the workout: about 25 for easy, 40 for normal, 60 for hard. It also sets how close to the limit sets are
pushed, as written in section 7. Two workouts with identical reps and weights can be an easy day and a hard
day, depending on what is in them. That difference lives on the exercise, so it is explicit and editable.
The three budget numbers are settings and the only guesses in the model; the feel tap tunes them (below)."""),
("""- Loaded exercises mostly move by level instead. Cost stays, the weight climbs.

**Defaults learn.**""",
 """- Loaded exercises mostly move by level instead. Cost stays, the weight climbs.
- Seconds per set well above the seed for its cost band, over several workouts: cost in play goes up by
  one; well below, down by one. The rest the user actually takes is the honest signal of what a set costs.

**The budget learns.** Two "too much" feel taps in the last four workouts at the same energy lower that
energy's budget by a tenth; two "easy" taps raise it by a tenth, inside a sane band. A tap after a plain
stop does not count. No question is ever asked per set.

**Defaults learn.**"""),
# 8.8
("""- **Energy and time never move a level.** The progression never changes what is in a workout.""",
 """- **Energy and time never move a level.** The progression never changes what is in a workout.
- **Energy and time are two budgets, spent together.** Neither can be overspent; a workout that does not fit
  is shorter, never heavier."""),
# settings
("| The goal: rep ranges, lifts per workout, movement days | from the template | any sensible range |",
 "| The goal: what to cover in order, reps-by-cost table, movement days | from the template | any order; any of the three tables |\n| Fatigue budget per energy level | 25 / 40 / 60 | easy 15 to 35, normal 30 to 55, hard 45 to 80 |"),
# section 13
("""  step you are on. No screen assumes the user knows the vocabulary. Movement patterns (squat, hinge, push,
  pull) stay inside the builder; the user only ever sees exercise names and levels.""",
 """  step you are on. No screen assumes the user knows the vocabulary. Movement patterns (squat, hinge, push,
  pull) are never a label on a row; they are one index the user can choose to browse by."""),
("- **Progress.** Workouts per month over time. Level trend per pattern. Days active this month.",
 "- **Progress.** Workouts per month over time. Level trend per exercise, grouped by the chosen index. Days active this month."),
# open questions
("""- **Cost defaults are guesses.** The 1 to 5 scale and the examples need real use, and the drift rules
  need to be watched for exercises that drop too fast.""",
 """- **The budget numbers are guesses.** 25, 40 and 60 need real days; the feel tap should correct them, but
  how fast is untested. The cost drift rules need to be watched for exercises that drop too fast."""),
("""- **A weekly cost budget.** Whether to cap how many cost-5 workouts land in a week, or trust the energy
  pick.""",
 """- **A weekly budget.** Whether to cap how many hard workouts land in a week, or trust the energy pick."""),
# feature notes
("- `EXERCISES.md`: what an exercise is, its levels and how-to, the library, and the indexes it can be browsed by.",
 "- `EXERCISES.md`: what an exercise is, its levels and how-to, the library, and the indexes it can be browsed by.\n- `WORKOUT.md`: a workout as two budgets, fatigue and minutes, spent in the goal's priority order; reps by\n  cost; how the budgets learn."),
])

E = r'D:\Working\fitness\docs\app\EXERCISES.md'
patch(E, [
("""- **A cost, 1 to 5.** How much a hard set takes out of the whole body. The energy pick uses it to decide
  what goes in a workout. It has a default and can be overridden.""",
 """- **A cost, 1 to 5.** How much one hard set takes out of the whole body. Derived from the exercise: how
  much muscle moves (1 to 3), plus one if the load goes through the spine or the body hangs from the arms,
  plus one if the load can get heavy relative to bodyweight. The energy budget is spent in it, and the rep
  range follows it. It can be overridden."""),
("""- **Movement pattern.** Squat, hinge, push, pull, core, carry, arms, shoulders or legs. This is the slot
  the exercise fills when the builder puts a workout together.""",
 """- **Movement pattern.** Squat, hinge, push, pull, core, carry, arms, shoulders or legs. This is the slot
  the exercise fills when the builder puts a workout together. No pattern is main or accessory; the goal
  puts them in an order."""),
("""The workout builder works in movement patterns and asks the library for exercises that fit the location's
equipment; energy picks among them by cost; the progression decides the level; the timing model prices the
sets.""",
 """The workout builder (`WORKOUT.md`) works in movement patterns and asks the library for exercises that fit
the location's equipment; energy picks among them by cost and spends its fatigue budget in it; the cost
also picks the rep range; the progression decides the level; the timing model prices the sets in minutes."""),
("""- Change a level because of the day, the location, or the calendar.""",
 """- Call an exercise main or accessory. Cost and the goal's order do that work.
- Change a level because of the day, the location, or the calendar."""),
])

M = r'C:\Users\derek\.claude\projects\D--Working-fitness\memory\fitness-app-intent.md'
patch(M, [
("a cost 1 to 5 per exercise, two questions per workout (energy\neasy/normal/hard; minutes on a slider 10 to 120),",
 "a cost 1 to 5 per exercise (derived: muscle mass 1-3, +1 spine/hang, +1 heavy load), two questions per workout\n(energy = fatigue budget 25/40/60 of summed set costs; minutes = time budget, slider 10 to 120). NO main vs\naccessory (dropped 2026-10-15): the goal is a priority order of patterns, reps follow cost; see docs/app/WORKOUT.md."),
])
print('ok')
