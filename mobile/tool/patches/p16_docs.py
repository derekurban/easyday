import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

D = r'D:\Working\fitness\docs\app'

# ---------------- WORKOUT.md: rewrite the model sections
W = D + r'\WORKOUT.md'
t = io.open(W, encoding='utf-8').read()
start = t.index('# Workout')
end = t.index('## How it is built')
new_head = '''# Workout

A workout fills the minutes the user has with the exercises the goal lists, then turns three dials on each
exercise to match the energy they picked. Time is the hard edge. Energy never changes which exercises are
in the workout, only how hard each is asked. Cardio and stretching take the shares the user set, and spare
minutes go where the user said. There is no main lift, no accessory, and nothing a user has to understand
about the engine to set it up.

## What it is

- **Time is filled, always.** Every set has a price in seconds. The builder fits the listed exercises, then
  spends what is left as the goal says: more exercises, cardio, or rest.
- **A level is strength, not a weight.** A loaded exercise's level is an estimated max; a bodyweight
  exercise's level is a version. The level never says how many reps. The workout chooses an
  **expression** of it, and the weight follows (below).
- **Energy is three dials, never a pick.** Each exercise gets an intent for today: light, working or
  extra. Intent sets the expression, the sets and the reserve. The same exercises appear at every energy,
  so for the same minutes hard is never emptier than normal, and normal never emptier than easy.
- **Intent is a prescription, not a judgement.** The progression never hears which intent an exercise was
  given. It judges what happened against the exercise's working level.

## Difficulty

Every exercise is easy, medium or hard: how much one hard set takes out of the whole body. Three dots on
every row, a word on the card, an index in the catalog, and an override on the card. The library carries a
finer number underneath; the user never sees it.

## Expressions

| Expression | Reps | Weight, as a share of the level | Rest after a set |
|---|---|---|---|
| Heavy and few | 4 to 6 | about 85 % | 3 minutes |
| Middle | 8 to 12 | about 70 % | 90 seconds |
| Light and many | 12 to 15 | about 60 % | 60 seconds |

The goal says which reps it likes, in one of those three words. Hard exercises train in that expression;
medium ones one step lighter; easy ones two steps lighter, so a strength goal squats heavy and curls
light, and a fitness goal does everything light and many. Hitting the top of the range in any expression
raises the level by one step, and every expression moves by at least one plate step per level, so progress
is always visible whichever reps the user likes. Changing the reps changes the weight, never the level.
For bodyweight, the version is the weight: the light expression is one version down for more reps.

Holds keep their own ranges in seconds. Bodyweight versions keep their floor, so a version is never asked
for fewer reps than make sense for it. Max estimates get loose past twelve reps, so the light expression
stops at 15 for loaded lifts.

## Time per set

Generous defaults, replaced by the user's own seconds per set once the timing model has a few workouts.
Each set is work plus rest plus transition, rounded up to the next 15 seconds.

| Part | Default |
|---|---|
| Work | 3 s per rep at the top of the range, or the hold seconds |
| Rest after | by expression, above |
| Transition | 15 s per set, plus 60 s per change of exercise |
| Warm-up sets | two, 60 s each, on loaded hard exercises; never logged |
| Circuit mode | rest 45 s flat, change 20 s |

## The working level

Every exercise has a working level: its level, its working set count (from the goal, three by default,
settable 2 to 5), and the rep range of its expression. Sets stay inside that band for good; progress is
the level rising, never the sets. "Hit" means a set reached the top of the range. "In range" means it
reached the floor but not the top. "Short" means it did not reach the floor.

## Intents

| Intent | Expression | Level | Sets | Target |
|---|---|---|---|---|
| Light | one lighter | the user's (bodyweight: one version down) | working sets minus one, at least two | two reps shy of the top |
| Working | the goal's | the user's | the working sets | the top |
| Extra | the goal's | the user's | the working sets plus one | the top |

Light is "do something": the same level in a lighter expression, with reps in reserve and a set fewer.
Nobody is demoted for picking easy. Working is the proper work. Extra is the proper work plus one more set,
the one-off probe that shows the next level is already there.

## Energy

| | Recipe |
|---|---|
| Easy | light everywhere; two exercises at working, easy and medium ones first, the longest-waiting among them |
| Normal | working everywhere |
| Hard | extra on the hardest one (a setting: one to five, or all), working on the rest |

No budgets, no points. The same list at every energy; only the dials move. When minutes are short the trim
order is light sets, then extra sets back to working, then the last exercise on the list, so a hard day in
a tight window degrades to a normal day before it loses an exercise.

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

'''
t = t[:start] + new_head + t[end:]
io.open(W, 'w', encoding='utf-8', newline='\n').write(t)

patch(W, [
("""1. **The window** is the minutes picked, minus the cardio and stretching shares from the sliders in
   `COVERAGE.md`. There is no separate warm-up block yet (`IDEAS.md`); loaded exercises at cost 4 and 5
   carry their own warm-up sets.
2. **Pick an exercise per pattern** in the rotation item, from what the location has. Where there is
   more than one candidate, coverage chooses (`COVERAGE.md`). On easy, anything above cost 3 swaps down
   to a cheaper exercise of the same pattern. Hard never introduces an exercise the user has not practised.
3. **Assign intents** by the recipe, and give each exercise its intent's sets.
4. **Price it** in points and minutes. Over points: downgrade from the end of the list, working to light.
   Over time: drop sets from light exercises first, then drop the last exercise. Under both: add a set to
   the highest-intent exercise that has room (light up to 3; working stays at the working sets; extra is
   the working sets plus one), then the next; when every exercise is full and both have room, add one
   more pattern, chosen by coverage. Sets never go past the band; spare room becomes another exercise,
   then cardio.
5. **Cardio and stretching close it.** Stretching takes its share last; cardio takes its share before
   that, plus any slack the lifting left. With both sliders at zero the slack is rest and the workout
   says "no rush."
6. **Order** extra and working first, light last, and within a tier costliest first.""",
 """1. **The window** is the minutes picked, minus the cardio and stretching shares. There is no separate
   warm-up block yet (`IDEAS.md`); loaded hard exercises carry their own warm-up sets.
2. **Pick an exercise per pattern** in the rotation item, from what the location has. Where there is
   more than one candidate, coverage chooses (`COVERAGE.md`). Energy plays no part.
3. **Assign intents** by the recipe. Each gets its expression, its sets and its target.
4. **Fit the minutes.** Over: light sets first, then extra sets back to working, then the last exercise on
   the list, then the one that is left shrinks. Patterns dropped here come back first if room appears.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest.
6. **Cardio and stretching close it.** Stretching takes its share last; cardio takes its share before
   that, plus any slack the lifting left when spare minutes are not rest.
7. **Order** extra and working first, light last, and within a tier hardest first."""),
("""The user can reshuffle, swap any exercise for another of the same pattern available here, or edit today's
level from the row. Levels follow the exercise, so none of that costs progress. A swap is repriced; if it
breaks the budget, one line says what moved.""",
 """The user can reshuffle, swap any exercise for another of the same pattern available here, or edit today's
level from the row. Levels follow the exercise, so none of that costs progress. A swap is repriced in
minutes; if it no longer fits, one line says what moved."""),
("""| Energy | Mix | Points | Lifting minutes | Filler |
|---|---|---|---|---|
| Easy | goblet squat working, push-ups working, pull-ups light, plank light, curl light | 17 of 20 | 24 | 16 min cardio or rest |
| Normal | squat working, pull-ups working, bench working, plank light, curl light | 38 of 40 | 38 | 2 min |
| Hard | squat extra, bench working, pull-ups working, plank light; curl dropped for time | 51 of 60 | 39 | none |

Hard is under budget because time binds first, which is the honest answer at 45 minutes.""",
 """| Energy | The same four exercises | Sets | Expression on the squat |
|---|---|---|---|
| Easy | squat light, bench light, pull-ups light, plank working, curl working | 2 + 2 + 2 + 3 + 3 | middle, 8 to 12, at 70 % of the level |
| Normal | all working | 3 each | heavy, 4 to 6, at 85 % |
| Hard | squat extra, the rest working | 4 + 3 + 3 + 3 + 3 | heavy, 4 to 6, at 85 % |

Same squat, same bench, same pull-ups at every energy. Easy is the same strength expressed lighter with a
set fewer; hard is one more set on the squat. In a tighter window the extra set goes before any exercise
does."""),
("| Working sets | 3 | Settings → Goal, 2 to 5 |\n| Rep range per cost band | from the template | Settings → Goal, three range controls |\n| Extras on a hard day | 1 | Settings → Goal, 1 to 5 or all |\n| Effort budget, easy / normal / hard | 20 / 40 / 60 | Settings → Goal, under energy |",
 "| Working sets | 3 | Settings → Goal, 2 to 5 |\n| Reps you like | from the template: heavy and few, middle, or light and many | Settings → Goal |\n| Hard day pushes | 1 | Settings → Goal, 1 to 5 or all |\n| Spare minutes go to | more exercises | Settings → Goal: more exercises, cardio, rest |\n| Difficulty, per exercise | library default | the exercise card: easy, medium, hard |"),
("""- Label an exercise main or accessory, or let a label decide what is trimmed.
- Let intent change a verdict, or a verdict change an intent.
- Spend past the budget or the minutes. A workout that does not fit is lighter in intent, never longer.
- Ask for effort per set.""",
 """- Label an exercise main or accessory, or let a label decide what is trimmed.
- Let energy pick or swap an exercise. Energy only turns the dials.
- Let intent change a verdict, or a verdict change an intent.
- Show a number the user has to understand the engine to set.
- Ask for effort per set."""),
("""- Whether the budget should keep growing past an hour for users who genuinely train long.
- Whether easy's two working exercises should rotate like the working turns do, or always be the first two.""",
 """- Whether the light expression should also be used by the time fit on normal days, picking lighter reps on
  the small exercises when the window is tight, within what the goal allows."""),
])

# fix any leftover "Spend past the budget" wording variants
t = io.open(W, encoding='utf-8').read()
t = t.replace("- Spend past the budget or the minutes. A workout that does not fit is shorter, never heavier.\n", "")
io.open(W, 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- EXERCISES.md
patch(D + r'\EXERCISES.md', [
("""  - *By weight.* A starting weight and a step. Each level is one step heavier. Barbells, dumbbells,
    machines, kettlebells. The description stays the same; only the number moves.""",
 """  - *By weight.* The level is an estimated max; each level is one step stronger. The weight on the bar
    follows the reps the goal likes: heavier and fewer, or lighter and more, are the same level. Barbells,
    dumbbells, machines, kettlebells. The description stays the same; only the number moves."""),
("""- **A cost, 1 to 5.** How much one hard set takes out of the whole body. The rubric: how much muscle
  moves (1 to 3), plus one if the load goes through the spine or the body hangs from the arms, plus one if
  the load can get heavy relative to bodyweight. The library carries the number; the three parts are a
  mechanism the rows can be tagged with later (`IDEAS.md`). The energy budget is spent in cost, and the
  rep range follows it. It can be overridden.""",
 """- **A difficulty: easy, medium or hard.** How much one hard set takes out of the whole body. The library
  carries a finer number underneath (the rubric: how much muscle moves, plus the spine or the arms carrying
  the load, plus a load that can get heavy) and folds it to three. A hard day pushes the hard ones first;
  easier exercises get more reps and less weight. It can be overridden on the card."""),
("| **Progression type** | by weight, by version | seeing which exercises have written levels |",
 "| **Progression type** | by weight, by version | seeing which exercises have written levels |\n| **Difficulty** | easy, medium, hard | what a hard day will push, what an easy day keeps at full |"),
("""| Cost, per exercise | library default | the exercise card |""",
 """| Difficulty, per exercise | library default | the exercise card |"""),
])

# ---------------- APPLICATION.md
A = D + r'\APPLICATION.md'
patch(A, [
("""- **Cost.** A number from 1 to 5 on each exercise for how much one hard set takes out of the whole body.
  Derived from the exercise itself (section 8.3), can be overridden, and drifts with practice and neglect.
- **Energy.** How much the user has to give today: easy, normal, or hard. Sets the effort budget of the
  workout and the recipe of intents that spends it.""",
 """- **Difficulty.** Easy, medium or hard, on each exercise: how much one hard set takes out of the whole
  body. Folded from a finer library number (section 8.3), can be overridden, and drifts with practice and
  neglect.
- **Expression.** How a level is lifted today: heavy and few, middle, or light and many. The weight follows
  the reps; the level does not move. The goal says which reps it likes.
- **Energy.** How much the user has to give today: easy, normal, or hard. Turns three dials on every
  exercise (expression, sets, reserve) and never changes which exercises are in the workout."""),
("""- **Effort.** Cost times sets times the intent's factor, summed over the workout. Energy is a budget of it.""",
 """- **Spare minutes.** What is left once the listed exercises fit: more exercises, cardio, or rest. One
  plain setting, tuned by the feel tap."""),
("""- **Rep range.** The band of reps per set, such as 8 to 12. It follows the cost of the exercise and the
  goal, so heavy compounds get the low range and small movements the high one. The target is always the
  top of the range at the current level.""",
 """- **Rep range.** The band of reps per set, such as 8 to 12. It is the range of the expression the
  exercise trains in today. The target is always the top of the range at the current level."""),
("""- **Goal.** What the plan is for: what each workout covers, in priority order, which reps-by-cost table it
  uses, and how often a movement day replaces a lifting day.""",
 """- **Goal.** What the plan is for: what each workout covers, in priority order, the reps it likes, and
  how often a movement day replaces a lifting day."""),
("""- **Goal.** One pick from a short list of templates, each stating what it means in practice: what a
  workout covers and in what order, the reps-by-cost table, and how often a movement day comes round.""",
 """- **Goal.** One pick from a short list of templates, each stating what it means in practice: what a
  workout covers and in what order, the reps it likes, and how often a movement day comes round."""),
("""**Goal translation** maps the chosen goal to the order patterns are covered in, the reps-by-cost table,
and how much of the rotation is movement workouts. Strength trains cost 4 and 5 exercises at 4 to 6 reps,
cost 3 at 6 to 10, cost 1 and 2 at 10 to 15; muscle and fitness shift the same three bands up (the table
is in `WORKOUT.md`). Changing the goal retranslates the plan but keeps every level, so changing goals never
means starting over.""",
 """**Goal translation** maps the chosen goal to the order patterns are covered in, the reps it likes, and
how much of the rotation is movement workouts. Strength likes heavy and few: its hard exercises train at
4 to 6, medium ones at 8 to 12, easy ones at 12 to 15. Muscle likes the middle; fitness likes light and
many (the table is in `WORKOUT.md`). Changing the goal retranslates the plan but keeps every level, so
changing goals never means starting over: the weight follows the reps."""),
("""A workout fills the minutes, then balances the effort of what is in it to the energy pick. The full
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
5. **Cardio and stretching close it,** each taking the share the user set, and cardio taking any slack.
   More minutes always mean at least as many sets.
6. **Order it** extra and working first, light last, costliest first within each.

Energy never changes a level and never changes how an exercise is judged. It only decides which intent
each exercise gets today.""",
 """A workout fills the minutes with the exercises the goal lists, then turns three dials on each to match the
energy pick. The full procedure is in `WORKOUT.md`; the shape is:

1. **Take the next rotation item.** A list of patterns in order. There is no main and no accessory.
2. **Pick an exercise for each pattern** from what the location has. Where several fit, coverage chooses
   the one whose muscle group is furthest behind (`COVERAGE.md`). Energy plays no part.
3. **Give each exercise an intent** from the energy recipe: easy is light everywhere with two at working;
   normal is working everywhere; hard is extra on the hardest, working on the rest. Intent sets the
   expression (the reps, and so the weight), the sets, and the reserve.
4. **Fit the minutes.** Light sets go first, then extra sets back to working, then the last exercise on
   the list. Hard in a tight window becomes normal before it loses an exercise.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest. Cardio and stretching
   close the workout with their shares. More minutes always mean at least as many sets.
6. **Order it** extra and working first, light last, hardest first within each.

Energy never changes a level, never changes which exercises are in the workout, and never changes how an
exercise is judged. It only decides which intent each exercise gets today."""),
("""Every exercise has a cost from 1 to 5 for how much one hard set takes out of the whole body, not just the
muscle. The default is derived, not guessed, from three things anyone can check on the exercise:""",
 """Every exercise has a difficulty, easy, medium or hard, for how much one hard set takes out of the whole
body, not just the muscle. The library keeps a finer number underneath, derived from three things anyone
can check on the exercise, and folds it to three for everything the user sees:"""),
("""So a deadlift is 5, a bench press 4, a pull-up 4, a pike push-up 3, a leg press 2, a curl 1. The user can
override any exercise's cost in the catalog, and the card shows which of the three it came from.

Energy is the user's side of the same number. It is an effort budget: cost times sets times the intent's
factor (light 0.6, working 1.0, extra 1.2), summed over the workout, about 20 for easy, 40 for normal, 60
for hard at forty minutes, growing with minutes up to an hour and flat past that. It also gives the recipe
of intents that spends it, as written in section 7. Two workouts with identical exercises can be an easy
day and a hard day, depending on the intents. The three budget numbers are settings and the only guesses
in the model; the feel tap tunes them (below).""",
 """So a deadlift and a bench press are hard, a pike push-up and a leg press medium, a curl easy. The user can
override any exercise's difficulty on its card.

Energy is the user's side of the same word. It is not a budget and not a number: it is the recipe of
intents in section 7, and difficulty decides where the recipe lands. A hard day pushes the hardest
exercises first; an easy day keeps the easy and medium ones at full. Two workouts with identical exercises
can be an easy day and a hard day, depending on the intents. Nothing here is a setting the user has to
understand the engine to use; the one knob, spare minutes, is in plain words and the feel tap tunes it."""),
("""**Cost in play** is the default or override, moved by the user's own history and clamped to 1 to 5:""",
 """**Difficulty in play** is the default or override, moved by the user's own history and clamped to the
three steps:"""),
("""- Not practised for the decay period: cost in play goes up by one. It is harder than it was.
- Bodyweight ceiling cleared for a few workouts in a row: cost in play goes down by one. The exercise that
  was the hard thing becomes the medium thing, and the next variant is offered as the new hard thing.
- Loaded exercises mostly move by level instead. Cost stays, the weight climbs.
- Seconds per set well above the seed for its cost band, over several workouts: cost in play goes up by
  one; well below, down by one. The rest the user actually takes is the honest signal of what a set costs.

**The budget learns.** Two "too much" feel taps in the last four workouts at the same energy lower that
energy's budget by a tenth; two "easy" taps raise it by a tenth, inside a sane band. A tap after a plain
stop does not count. No question is ever asked per set.""",
 """- Not practised for the decay period: difficulty in play goes up one step. It is harder than it was.
- Bodyweight ceiling cleared for a few workouts in a row: difficulty in play goes down one step. The
  exercise that was the hard thing becomes the medium thing, and the next version is offered as the new
  hard thing.
- Loaded exercises mostly move by level instead. Difficulty stays, the max climbs.

**Spare minutes learn.** Two "too much" feel taps in the last four workouts flip "more exercises" to
cardio; two "easy" taps flip cardio back. A tap after a plain stop does not count. No question is ever
asked per set."""),
("""- **Time is filled, effort is budgeted.** A workout that does not fit the budget is lighter in intent,
  never shorter in minutes; a workout that does not fit the minutes is shorter, never heavier.""",
 """- **Time is filled, energy turns dials.** A workout that does not fit the minutes trims light sets, then
  extra sets, then the last exercise; it is never heavier than it was asked to be."""),
("| The goal: what to cover in order, rep range per cost band, movement days | from the template | any order; any sensible ranges |\n| Extras on a hard day | 1 | 1 to 5, or all |",
 "| The goal: what to cover in order, the reps it likes, movement days | from the template | any order; heavy and few, middle, light and many |\n| Hard day pushes | 1 | 1 to 5, or all |\n| Spare minutes go to | more exercises | more exercises, cardio, rest |"),
("| Working sets | 3 | 2 to 5 |\n| Effort budget per energy level | 20 / 40 / 60 | easy 10 to 35, normal 30 to 55, hard 45 to 80 |",
 "| Working sets | 3 | 2 to 5 |"),
("| Cost of an exercise (per exercise, in the catalog) | library default | 1 to 5 |",
 "| Difficulty of an exercise (per exercise, on its card) | library default | easy, medium, hard |"),
("| Index the library is grouped by | muscle group | muscle group, body region, movement pattern, equipment, progression type |",
 "| Index the library is grouped by | muscle group | muscle group, body region, movement pattern, equipment, progression type, difficulty |"),
("""- **The budget numbers are guesses.** 20, 40 and 60 need real days; the feel tap should correct them, but
  how fast is untested. The cost drift rules need to be watched for exercises that drop too fast.""",
 """- **The expression shares are guesses.** 85, 70 and 60 per cent of the level are the usual table; real
  days will say whether the light expression lands too heavy for beginners. The difficulty drift rules
  need to be watched for exercises that drop too fast."""),
("""- `WORKOUT.md`: filling the minutes, intents and the effort budget, reps by cost, and judging against the
  working level.""",
 """- `WORKOUT.md`: filling the minutes, a level as strength and its expressions, intents and the energy
  dials, spare minutes, and judging against the working level."""),
])
t = io.open(A, encoding='utf-8').read()
t = t.replace("- **Working level.** Per exercise: the level, the working set count, and the rep range. What progression\n  judges against. See section 8.2.",
              "- **Working level.** Per exercise: the level, the working set count, and the rep range of its expression.\n  What progression judges against. See section 8.2.")
io.open(A, 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- IDEAS.md
patch(D + r'\IDEAS.md', [
("""- **Reserve sets at a discount.** Whether light sets with reps in reserve should cost less than their
  cost in the effort sum, once the feel tap has data.""",
 """- **An effort budget.** Points per set, summed and capped by energy, was the model until 2026-10-15. It
  balanced well but could not be explained to a user, so energy became three dials and spare minutes a
  plain setting. The budget could return as an internal guard if a long normal day ever feels like too much.
- **The time fit choosing expressions.** On a tight normal day, express the small exercises lighter (more
  reps, less rest) to fit more in, within what the goal allows."""),
("""- **Derived cost breakdown.** Tag each exercise with the three parts of the cost rubric (muscle mass,
  spine or hang load, heavy load) so the card can show where its cost came from. The mechanism exists;
  the 137 rows are not tagged.""",
 """- **Derived difficulty breakdown.** Tag each exercise with the three parts of the rubric (muscle mass,
  spine or hang load, heavy load) so the card can show where its difficulty came from. The library's finer
  number exists; the 137 rows are not tagged with the parts."""),
])

# ---------------- COVERAGE.md: easy's working turns wording
patch(D + r'\COVERAGE.md', [
("""- **Which exercises do the work on an easy day.** Easy gives two exercises a working turn; they are the
  two whose primary groups have the largest deficit, among those at cost 3 or under. An easy day is a
  catch-up day for whatever has been missed, at low cost.""",
 """- **Which exercises do the work on an easy day.** Easy gives two exercises a working turn; they are the
  two whose primary groups have the largest deficit, among the easy and medium ones. An easy day is a
  catch-up day for whatever has been missed, without the hard lifts."""),
])

# ---------------- memory
M = r'C:\Users\derek\.claude\projects\D--Working-fitness\memory\fitness-app-intent.md'
t = io.open(M, encoding='utf-8').read()
i = t.index('Model (docs/app/APPLICATION.md')
j = t.index('Vocabulary the user insisted on')
new = '''Model (docs/app/APPLICATION.md + WORKOUT.md, settled 2026-10-15, v0.7): a level is STRENGTH (loaded: estimated max;
bodyweight: version); an EXPRESSION (heavy 4-6 @85%, middle 8-12 @70%, light 12-15 @60%) picks reps and the weight
follows; the goal says which reps it likes. Difficulty per exercise is easy/medium/hard (3 dots; library cost 1-5
folded). Energy NEVER changes which exercises: it turns three dials per exercise via intents light (lighter
expression, a set fewer, reserve, neutral) / working / extra (+1 set, probe). Easy = light + two at working;
normal = working; hard = extra on the hardest N (setting). Time is always filled; trim order light sets ->
extra sets -> last exercise. NO points/budgets exposed or used (dropped 2026-10-15: unexplainable to users);
"spare minutes go to" more exercises / cardio / rest is the one knob, tuned by the feel tap. Working sets fixed
2-5; progress is the level, never the sets. Progression judges ONLY against the working level: light days neutral,
in-range holds, short of floor misses, working sets + extra set all at top = step up now. Muscle coverage chooses
between candidate exercises (COVERAGE.md). Custom exercises dropped. Library browsed by a user-picked index.

'''
t = t[:i] + new + t[j:]
io.open(M, 'w', encoding='utf-8', newline='\n').write(t)
print('ok')
