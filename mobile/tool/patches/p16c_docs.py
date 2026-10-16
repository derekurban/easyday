import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

D = r'D:\Working\fitness\docs\app'

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
procedure, with the numbers, is in `WORKOUT.md`; the shape is:""",
 """A workout fills the minutes with the exercises the goal lists, then turns three dials on each to match the
energy pick. The full procedure is in `WORKOUT.md`; the shape is:"""),
("""2. **Pick an exercise for each pattern** from what the location has. Where several fit, coverage chooses
   the one whose muscle group is furthest behind (`COVERAGE.md`). On easy, nothing above cost 3. Hard never
   introduces an exercise the user has not practised.
3. **Give each exercise an intent** from the energy recipe: easy is light everywhere with up to two at
   working; normal is working wherever the budget allows; hard is extra on the costliest, working on the
   rest, light past the budget. The working turns go to the exercises furthest behind on coverage on easy,
   and to the ones that have waited longest on normal and hard. How many extras hard gives is a setting.
4. **Price it and fit it.** Sets are priced in seconds by the timing model and in effort by cost times
   sets times the intent's factor. Over the budget: downgrade from the end. Over time: trim light sets,
   then drop the last exercise. Under both: add sets front to back, then one more pattern by coverage.
5. **Cardio and stretching close it,** each taking the share the user set, and cardio taking any slack.
   More minutes always mean at least as many sets.
6. **Order it** extra and working first, light last, costliest first within each.

Energy never changes a level and never changes how an exercise is judged. It only decides which intent
each exercise gets today.""",
 """2. **Pick an exercise for each pattern** from what the location has. Where several fit, coverage chooses
   the one whose muscle group is furthest behind (`COVERAGE.md`). Energy plays no part.
3. **Give each exercise an intent** from the energy recipe: easy is light everywhere with two of the easy
   and medium exercises at working, the ones furthest behind on coverage; normal is working everywhere;
   hard is extra on the hardest, working on the rest. How many pushes hard gives is a setting. Intent sets
   the expression (the reps, and so the weight), the sets, and the reserve.
4. **Fit the minutes.** Light sets go first, then extra sets back to working, then the last light exercise
   on the list, then the last working one. Hard in a tight window becomes normal before it loses an
   exercise.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest. Cardio and stretching
   close the workout with their shares. More minutes always mean at least as many sets.
6. **Order it** extra and working first, light last, hardest first within each.

Energy never changes a level, never changes which exercises are in the workout, and never changes how an
exercise is judged. It only decides which intent each exercise gets today."""),
("""repriced against both budgets. Every exercise carries a how-to at its level""", """repriced in minutes. Every exercise carries a how-to at its level"""),
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
