# APPLICATION

A habit-first training app. It decides what you do, adjusts how much, and is built so that one missed
workout never turns into a missed month. This document describes the logic of the application, not how it
is implemented. Diagrams of the same logic live in `docs/app-logic/`.

## 1. Purpose

The app exists to make exercise stick for years. It is not a performance tool. Strength, fitness and
capacity are expected side effects of showing up consistently; they are never the thing being optimised.

Every feature is judged by one question: **does this make the next workout more likely to happen?**
If a feature asks the user to think, plan, compare, or configure, it is working against the purpose.

## 2. Who it is for

**Primary user:** a person who wants to exercise more but finds the management of it, choosing what to
do, when, how much, and how to progress, frustrating enough that they stop. They are not a beginner to
movement and not an athlete. They may lift, they may walk or run, they want some mobility, and they do
not want to become an expert in programming. They train at home and at a gym, and sometimes nowhere in
particular.

**Secondary users:** other people with the same frustration. The app should work for them without
special casing, but the primary user's needs win when they conflict.

**Power users:** people who know what rate of progress they want. They get six plain-language settings
and a cost override per exercise. They never get to remove the guardrails.

### What goes wrong for this person

Ranked by how directly each one causes quitting.

1. **Deciding is the hardest rep.** "What do I do today?" is answered while tired and unmotivated. Every
   open question is an exit. Exercises, order, sets, weight, rest: each is a chance to not start.
2. **The dose is wrong and static.** Programs assume a fixed person. Real people have bad sleep, hard
   weeks, soreness, illness, and good days. Fixed progressions break within weeks. The two ways to be
   wrong cost very different amounts: too little loses a bit of growth, too much loses weeks.
3. **One missed day becomes a missed month.** Fixed schedules turn a skipped day into "I'll restart
   Monday." Streak counters make it worse: a broken streak feels like a reset to zero.
4. **Logging is a tax.** If recording a set takes more than a tap or two, logging stops, and then nothing
   can adapt.
5. **Progress is invisible day to day.** Strength changes slowly. Without a visible trend the work feels
   pointless. The wrong metrics, like streaks or calories, backfire.
6. **Life constraints shift.** Some days allow fifteen minutes, some an hour. Equipment changes with
   travel. An injury takes a movement off the table. All-or-nothing workouts fail on constrained days.
7. **Goals are vague and drift.** "Get fit" is not actionable, and the user should not need to know rep
   ranges. Goals also change over months and should not require starting over.

## 3. Principles

- Optimise for still training a year from now, not for the weight on the bar.
- Undertraining costs a little growth; overtraining costs weeks. Bias toward too easy, ramp slowly.
- The user makes one decision per visit: start or not. Everything else has a default.
- Two questions describe a day: how much energy, and how much time. Nothing else is asked.
- The user controls today. The app controls the trend.
- The app may refuse "more". It never refuses "less".
- Progress is earned on a progression. Hit the top of the range and the next level is yours.
- Energy changes what is in the workout and how hard you push. Time changes how much. Neither moves a level.
- Physical signals and mental signals are kept apart. "I couldn't" and "I didn't want to" never share a
  tap.
- Signals should be implicit where possible. Every explicit input must be one tap and skippable.
- Nothing is timed for the user. Timing is learned from the user.
- A miss is expected data, not failure. Levels decay gently and re-climb fast.
- Cardio and mobility are the floor: deliberately simple, always one tap away.
- Automations change defaults and send at most one nudge. They never act for the user.
- The settings are few and in plain words. The guardrails are not settings.
- Progress is shown as consistency and trend. Never streaks.

## 4. Vocabulary

- **Goal.** What the plan is for: what each workout covers, in priority order and up to how many, the rep
  band for each difficulty, and how often a movement day replaces a lifting day. Starts from a plain-language template such as
  "get stronger" or "build muscle"; every knob can be changed, and a changed template is a custom goal.
- **Movement pattern.** The building block of a plan: squat, hinge, push, pull, carry, core, arms,
  shoulders, legs, plus cardio and mobility blocks. Plans are written in patterns, not exercises. There is
  no main or accessory pattern; there is an order.
- **Exercise.** A specific implementation of a pattern with specific equipment. Barbell bench press and
  dumbbell floor press are two exercises for the same push pattern.
- **Progression and level.** Every exercise is a progression. A level is one notch harder: the next weight step for a
  barbell or machine, the next pair for dumbbells, the next variant for a bodyweight exercise. The user's
  position on each progression is their level.
- **Rep range.** The band of reps per set, such as 8 to 12. It is the range of the expression the
  exercise trains in today. The target is always the top of the range at the current level.
- **Difficulty.** Easy, medium or hard, on each exercise: how much one hard set takes out of the whole
  body. Folded from a finer library number (section 8.3), can be overridden, and drifts with practice and
  neglect.
- **Expression.** How a level is lifted today: heavy and few, middle, or light and many. The weight follows
  the reps; the level does not move. The goal says which reps it likes.
- **Energy.** How much the user has to give today: easy, normal, or hard. Turns three dials on every
  exercise (expression, sets, reserve) and never changes which exercises are in the workout.
- **Time.** How many minutes the user has today, on a slider. Always filled: sets priced by the timing
  model, then cardio or rest for the remainder.
- **Working level.** Per exercise: the level, the working set count, and the rep range of its expression.
  What progression judges against. See section 8.2.
- **Intent.** What a workout asks of one exercise today: light (85 % of the usual weight or one version
  down, full sets, fewer exercises), working (the working level), or next level (one step up, every set). A
  prescription, never a judgement.
- **Spare minutes.** What is left once the listed exercises fit: more exercises, cardio, or rest. One
  plain setting, tuned by the feel tap.
- **Muscle map.** The app's one view of the body: the muscles, and strain points, how much work each
  has taken (0.00 to 1.00) and how much is left after the strain point decay. Chooses between candidate
  exercises; never touches a level. See `MUSCLE_MAP.md`.
- **Timing model.** Learned seconds per set per exercise, including rest, from the gaps between set taps.
- **Location.** A place the user trains, with an equipment profile. Location decides which exercise
  implements each pattern and how high each progression can go.
- **Rotation.** The ordered list of workouts in the plan. The next workout is always the next item,
  regardless of the calendar.
- **Workout.** One visit. Built from the next item in the rotation, implemented for the current location,
  filled for the chosen energy and time.
- **Movement workout.** The alternative to a lifting workout: a cardio duration or a short mobility
  routine. Requires no decisions beyond picking it.
- **Set outcome.** Hit the top, a rep count below it, or not attempted. See section 8.
- **Mode.** Straight sets (all sets of one exercise, then the next) or circuit (one set of each exercise per
  round). Chosen before starting; it changes the order, nothing else.
- **Index.** A way of grouping the library for browsing: by muscle group (the default), body region,
  movement pattern, equipment, or progression type. The user picks one; it never changes what gets built.
- **Stop reason.** Why a workout ended early: out of energy, out of time, something hurts, or no reason.
  No reason is allowed and carries no penalty: nothing is judged and no default moves.
- **Decay.** What happens to a level, and to a cost, when an exercise is not practised for a while.
- **Person state.** Active, at risk, or away. Derived from recent attendance; drives defaults and
  reminder tone.

## 5. The core loop: one workout

1. **Open the app.** It detects context: the likely location, days since the last workout, and whether
   the calendar is packed.
2. **Today asks two things, both already answered.** How much energy, and how much time. Time is the minutes
   the user has, or, with the time limit switched off, how many exercises, starting at the goal's ideal. The
   defaults come from last time and the calendar. After a week away, energy defaults to easy. Changing either
   is one tap or one drag.
3. **It shows what that makes of today.** The next item in the rotation, implemented with the current
   location's equipment: its name, one line of numbers, and a body map of what it works, with a line or two
   saying why and what has not been worked lately. Swapping to a movement workout and changing location
   happen here.
4. **Plan it.** The plan lays the workout out in order: the warm-up, each exercise with its level, sets and
   minutes, then cardio and stretching. One tap each to reshuffle, swap an exercise for another of the same
   pattern, edit today's level (or save it as the new level), move an exercise up or down, pick the warm-up,
   leave out cardio or stretching today, and choose one at a time or circuit. Start starts the clock.
5. **Do the workout.** A strip of the whole workout runs across the top, warm-up to stretching, and one thing
   is asked at a time. A set is lifting from the moment the user says I'm ready (Start, for the first) until
   the reps go in: one tap on the exercise's range, with one button for anything under it and one for
   anything over. Then the guide says rest, with the planned rest as a guide only, and I'm ready starts the
   next set, or after the last set the next item. Warm-up sets for loaded hard exercises are shown in the
   rest before them and never logged. The last set can be corrected by tapping it. A later item on the strip
   can be jumped to; anything passed over is skipped and not judged. Ending the workout early asks one tap
   for the reason: out of energy, out of time, or something hurts, or none.
6. **Finish.** An optional one-tap rating: easy, right, or too much. Skipping is fine. Then the workout is
   logged: one line about what changed, the time it took against the plan, and where it went, lifting and
   rest.
7. **The app updates.** History is written, the progression judges each exercise, the timing model updates
   seconds per set, person state is recomputed, the rotation advances, and one line explains what changed.

There is no step where the user plans, chooses exercises, or decides on weights. There is no "Tuesday
workout" to miss. Whenever they come back, the next workout is waiting.

**Closure.** A finished workout closes the day. Today shows what changed and that the next workout is
ready tomorrow; nothing else is waiting. The next workout appears on the next calendar day, or at once if
the user asks for it. One workout a day is the shape people recognise; back-to-back is the exception.

## 6. Onboarding and goal translation

Onboarding asks for as little as possible and infers the rest from the first few workouts.

- **Goal.** The user's own, named and shaped in plain words. Templates are suggestions that fill every
  knob at a tap: what a workout covers, the reps it likes, how many exercises and sets, how often a
  movement day comes round. Any knob can be changed right there, or later in settings. The same goes for
  locations: name it, tick what is there, or fill it from a template first.
- **Experience.** Rough self-rating, used only to seed starting levels conservatively.
- **Availability.** Rough days per week. Used to choose the rotation length, not to fix days.
- **Locations.** At least one, the user's own: a name and an equipment list, filled from a template such
  as "commercial gym", "home with dumbbells and a bench", or "nothing" if that helps.
- **Units.** Kilograms or pounds. Loads are stored in kilograms; steps and display follow the chosen unit.

**Goal translation** maps the chosen goal to the order patterns are covered in, the reps it likes, and
how much of the rotation is movement workouts. Strength likes heavy and few: its hard exercises train at
4 to 6, medium ones at 8 to 12, easy ones at 12 to 15. Muscle likes the middle; fitness likes light and
many (the table is in `WORKOUT.md`). Changing the goal retranslates the plan but keeps every level, so
changing goals never means starting over: the weight follows the reps.

## 7. Building a workout

A workout fills the minutes with the exercises the goal lists, then turns three dials on each to match the
energy pick. The full procedure is in `WORKOUT.md`; the shape is:

1. **Take the next rotation item.** A list of patterns in order. There is no main and no accessory.
2. **Pick an exercise for each pattern** from what the location has. Where several fit, the muscle map
   chooses by strain points: strain-free primary muscles first; a pattern with none sits out for another
   (`MUSCLE_MAP.md`). Energy plays no part.
3. **Fit the minutes at normal**, less the warm-up, and spend the spare minutes as the goal says: more
   exercises, cardio, or rest. With the time limit off, the count decides instead and the minutes follow.
   This list is the workout at every energy.
4. **Turn the dials** for the energy picked: easy is light everywhere with two of the easier exercises at
   working, the ones that have waited longest; normal is working everywhere; hard is the next level on
   the hardest, every set, as many exercises as the setting asks. Intent sets the expression (the reps,
   and so the weight), the sets, and the reserve. The expression never changes with energy; a hard day is
   the same sets and minutes one step heavier, so it always fits.
5. **Cardio and stretching close it** with their shares. More minutes always mean at least as many sets.
6. **Order it** hardest first; at the same difficulty, extra and working before light. Every row and the
   whole workout are shown against the user's usual: "60 %", "usual", "+1 set".

Energy never changes a level, never changes which exercises are in the workout, and never changes how an
exercise is judged. It only decides which intent each exercise gets today.

The user can reshuffle the exercises of today's workout, or swap any one of them for another exercise of the
same pattern available at the location. Levels follow the exercise, so a swap never costs progress. A swap is
repriced in minutes. Every exercise carries a how-to at its level, and the workout shows the muscle
groups it will work.

**Movement workouts** bypass all of this. Cardio is a single duration with a perceived-effort tap at the
end. Mobility is one of a few fixed routines. They exist so that "I don't want to lift" still produces a
workout rather than nothing. They also appear inside lifting workouts as the cardio and stretching
shares at the end (`WORKOUT.md`). A warm-up block opens a lifting workout: a few minutes of easy moves,
none, 3, 5 or 8, inside the minutes, picked on the plan and kept for next time.

## 8. How the app adjusts

Four things adjust, each with one rule. Section 8.8 says how they fit together. Section 9 says what can be
tuned.

### 8.1 Reading the signals correctly

Every set has exactly one outcome.

The instruction is always "as many as you can with good form"; the range is a verdict, not a target.

- **The top or more.** Ready for more. One tap.
- **In range.** The floor to just under the top. The number is logged, one more tap. This is what training
  looks like: the level holds, not ready to go up, no reason to go down.
- **Short.** Under the floor. The number is logged. The weight is too much: the only outcome that can
  lower a level, and only at the working level.
- **Read by worth.** A set lifted at a different weight than the usual, a hard day's next level, is
  converted to what it would be at the usual weight before it is read, by the percent-of-max table.
- **Not attempted.** The set never started. This happens when time trimmed it, when the intent was light,
  or when the user stopped early. Never attempted sets are never failures.

Stop reasons are separate from set outcomes, and each one has one owner:

- **No reason.** Nothing. The sets done are kept; no level and no default moves.
- **Out of energy.** Nudges the energy default toward easy. The one exercise it cut mid-way at the working
  level is a miss; everything after it is not attempted.
- **Out of time.** Nudges the time default toward short. Never a progression signal.
- **Something hurts.** Pauses the pattern. See 8.6.

Why this matters: "I couldn't" and "I didn't want to" look identical in a set count but mean opposite
things. One says the level is too high. The other says the day was too big. Confusing them makes the app
lower levels when it should shrink workouts, and shrink workouts when it should lower levels.

### 8.2 The progression: per exercise

Each exercise has a working level: its level, its working set count (from the goal, three by default),
and the rep range for its cost and the goal. The user does not manage reps. They lift, and the progression
reads the result against the working level, and against nothing else: not the energy pick, not the intent
the builder gave the exercise, not what else was in the workout.

- **Neutral.** The exercise was asked for less than its working level today: one level down, or fewer than
  the working sets. Nothing moves. A light day never breaks a streak.
- **Hit.** At the working level, every working set hit the top. Hit streak plus one. After the step-up
  number of hits in a row (default one), the level rises by one and reps fall back toward the floor.
- **Step up now.** A hard day trains the exercise at the next level on every set. The floor on every
  working set there shows it is already yours; the count is skipped. A set that falls short at the next
  level is read by its worth at the usual weight, so one rep short usually holds rather than misses.
- **Hold.** At the working level, every set in range and none short. The hit streak resets; nothing else
  moves. Not ready to go up, no reason to go down.
- **Miss.** At the working level, any set short of the floor, or the working sets cut short by an energy
  stop. Miss streak plus one. After the step-down number of misses in a row (default two), the level drops
  by one. The floor is where the weight is wrong; the top is where it is earned.
- **Calibration.** The first time an exercise appears, a feel tap of easy with every set at the top steps
  up straight away, so a conservative starting level corrects in one workout.

Intent is how the builder asks; the working level is how the result is read. A user who picks easy for a
month keeps every level. A user who picks normal every day and does the work progresses everything.

**How-to follows the level.** Each level of a bodyweight progression carries its own description, so when
the level changes, the instructions change with it. Loaded exercises keep one description; only the weight
moves.

**Levels by equipment.** Barbells and machines step by the smallest practical weight increment, dumbbells by
the next pair. Bodyweight exercises step by variant, for example the push-up progression: wall, incline, knee,
floor, feet elevated, pike, archer. A half-level such as a pause or a slower tempo can sit between two
variants when the jump is large. If the location has a vest, a dip belt, or a loadable backpack, loaded
variants are further levels. Otherwise the hardest variant is the ceiling.

**At the ceiling.** When no higher level exists, the range opens upward and the target becomes beating the
best total reps across the sets. There is always a next thing without inventing equipment.

**Starting levels.** From experience level, or from the user's history with another exercise in the same
pattern, scaled and clamped between half and double.

### 8.3 Energy and cost: per workout

Every exercise has a difficulty, easy, medium or hard, for how much one hard set takes out of the whole
body, not just the muscle. The library keeps a finer number underneath, derived from three things anyone
can check on the exercise, and folds it to three for everything the user sees:

- **How much muscle moves.** One small group alone (biceps, calves, forearms): 1. One big group, or an
  isolation of one (leg curl, chest fly, lateral raise): 2. Several groups at once: 3.
- **Plus one if the load goes through the spine or the whole body hangs from the arms:** squats,
  deadlifts, overhead presses, carries, pull-ups, dips.
- **Plus one if the load can get heavy relative to bodyweight:** a barbell or trap bar on a big compound.

So a deadlift and a bench press are hard, a pike push-up and a leg press medium, a curl easy. The user can
override any exercise's difficulty on its card.

Energy is the user's side of the same word. It is not a budget and not a number: it is the recipe of
intents in section 7, and difficulty decides where the recipe lands. A hard day pushes the hardest
exercises first; an easy day keeps the easy and medium ones at full. Two workouts with identical exercises
can be an easy day and a hard day, depending on the intents. Nothing here is a setting the user has to
understand the engine to use; the one knob, spare minutes, is in plain words and the feel tap tunes it.

**Difficulty in play** is the default or override, moved by the user's own history and clamped to the
three steps:

- Not practised for the decay period: difficulty in play goes up one step. It is harder than it was.
- Bodyweight ceiling cleared for a few workouts in a row: difficulty in play goes down one step. The
  exercise that was the hard thing becomes the medium thing, and the next version is offered as the new
  hard thing.
- Loaded exercises mostly move by level instead. Difficulty stays, the max climbs.

**Spare minutes learn.** Two "too much" feel taps in the last four workouts flip "more exercises" to
cardio; two "easy" taps flip cardio back. A tap after a plain stop does not count. No question is ever
asked per set.

**Defaults learn.** The energy and time defaults start from the last workout. Two energy stops in the last
four workouts make easy the default. A time stop makes the minutes the user actually had the default. A
clean workout brings the defaults back to what was picked. There is one window for this, the last four
workouts, and no other thresholds.

### 8.4 Time and the timing model

The timing model keeps, per exercise, a running average of seconds per set at the user's current reps,
including the rest that follows. It is seeded by the expression, roughly four minutes for a heavy set and ninety
seconds for a cost-1 move, and learned from each workout, weighted toward recent ones. Three sets of
deadlifts price at twelve minutes until the user's own history says otherwise.

Every item on the strip runs from when it starts until the next one does, so an exercise's time holds its
sets, the rest between them, the rest after the last, and setting up the next. After a workout that time,
less the change-over and any warm-up sets the plan prices on their own, over the sets done, is what an
exercise learns from; a circuit shares its time out by sets. The time dial uses the model to make the
minutes real, as in section 7, so it follows the user as they get faster or start resting longer.

Two words, used the same way everywhere. **Lifting** is a set, from I'm ready until the reps are in.
**Rest** is everything between sets: catching your breath, moving to the next exercise and setting it up.
During a workout the current exercise shows its lifting and rest so far; afterwards the log shows them for
the workout and for each exercise, in minutes or, by a setting, as a share of the time. Rest never gates
anything: it counts up, the planned rest (by the exercise's reps, or ninety seconds between rounds of a
circuit) is only a guide, and the next set starts when the user says so. A setting can make the planned
rest a timer that starts the next set by itself.

### 8.5 Decay and breaks: per person

- **Level decay.** For every decay period an exercise is not done, default three weeks, its level drops by
  one, never below where it started. A decayed level re-climbs fast: the first clean workout at the top
  steps it straight back up regardless of the step-up setting. A month off costs one easy workout, not a
  slow rebuild.
- **After a week away.** The next workout defaults to easy, and hard lifts start one level down. That is
  the whole comeback. There is no comeback mode, no load factor, no ramp.
- **Person state.** Three days without a workout: at risk, one gentle nudge that suggests easy or a
  movement workout. Seven days: away, reminders go quiet. Any workout logged: active. See section 10.
- **A goal change** retranslates the rep ranges and keeps every level.

### 8.6 Pain

A pain stop pauses that pattern for the pain rest period, default seven days. The workout builder
substitutes another pattern or a movement block. The pattern returns on its own one level down, and the
user can pause it again with one tap. Anything longer than a pause needs a human, not an app.

### 8.7 To the human, always

- **After each workout**, one line about what changed and why, such as "Rows step up next time: you hit
  twelve on every set." Or "Bench stays: eight, eight, six. Next time."
- **Between workouts**: workouts per month, level trend per pattern, days active this month. Never streaks.
- **On each exercise card**: the level, the average time per set, the best total at this level, and the
  cost with its override.

This is the loop that actually decides adherence and the one with the least specification so far.

### 8.8 How it fits together

- **Order after every workout:** person state and decay, then the progression per exercise, then the timing
  model, then the defaults for next time, then the one line to the human.
- **Every workout record carries its context:** energy, time, whether the user chose them, stop reason,
  reps and timestamps per set. Judgement reads context first.
- **Each signal has one owner.** Reps below the top belong to the progression. Energy stops and time stops
  belong to the defaults. Gaps belong to decay. Pain belongs to the pause. A signal never feeds two rules.
- **Not scheduled, not attempted, and below the top are three different things.** Only below the top in a
  normal or hard workout can move a level down.
- **Energy and time never move a level.** The progression never changes what is in a workout.
- **Time is filled, energy turns dials.** A workout that does not fit the minutes trims light sets, then
  extra sets, then the last exercise; it is never heavier than it was asked to be.
- **Intent in, working level out.** The builder prescribes; the progression reads the result against the
  working level and never asks what was prescribed.
- **Hold rather than guess.** Any ambiguity means no change. Nothing ever asks the user a question to
  resolve it.

## 9. Settings and guardrails

### 9.1 Settings

Six settings, in plain words, each with a range. Plus one override per exercise.

| Setting | Default | Range |
|---|---|---|
| The goal: what to cover in order, rep ranges tagged by difficulty, movement days | filled from a template | any order; up to six ranges, those sharing a tag cycling by workout |
| Different exercises in a workout: fewest, ideal, most | 2, 4, 6 | 1 to 10 |
| Reps per exercise | the goal's range for its difficulty | any range |
| Hard day, next level on: tight, usual, long | 1, 2, 3 | 0 to 10 |
| Spare minutes go to | more exercises | more exercises, cardio, rest |
| Working sets: fewest, ideal, most | 2, 3, 4 | 1 to 6 |
| Cardio and stretching, share of every workout | 15 % / 10 % | 0 to 50 %, 0 to 30 % |
| Warm-up block (on the plan, kept for next time) | 5 minutes | none, 3, 5, 8 minutes |
| When the planned rest runs out | keep resting | keep resting, start the next set |
| Show lifting and rest as | minutes | minutes, share of time |
| Workouts at the top before a level steps up | 1 | 1 to 5 |
| Workouts below the bottom before a level steps down | 2 | 1 to 5 |
| Weeks before an unused level decays | 3 | 2 to 8, or off |
| Days away before easy is the default | 7 | 5 to 21 |
| Days a pattern rests after pain | 7 | 3 to 28 |
| Difficulty of an exercise (per exercise, on its card) | library default | easy, medium, hard |
| Index the library is grouped by | muscle group | muscle group, body region, movement pattern, equipment, progression type, difficulty |
| Reminder, calendar, position | each off | their own sections; `CALENDAR.md` and `LOCATION.md` list theirs |

Everything else in section 8 is a fixed rule or learned.

### 9.2 Guardrails

These cannot be changed by any setting.

- A set below the top always holds. A level never steps up on a workout with one.
- A level never moves on an easy workout, or on a workout stopped for energy or time.
- Energy and time change what is in the workout and how much, never the level.
- A decayed level never falls below where the exercise started.
- Rest never gates anything: it counts up, and the next set starts when the user says so. Only the warm-up,
  cardio and stretching blocks count down, and the planned rest starts a set by itself only when the user
  turns that on.
- At most one reminder per person-state transition.
- The app may refuse "more". It never refuses "less".

## 10. Person state

Derived from attendance only. Drives defaults and reminder behaviour.

| State | Entered when | What changes |
|---|---|---|
| Active | Any workout logged | Defaults from last time, normal reminders |
| At risk | Three days without a workout | One gentle nudge, suggests easy or a movement workout |
| Away | Seven days without a workout | Reminders go quiet, next workout defaults to easy, decayed levels apply |

The app never sends more than one reminder per transition. There is no comeback state: decay and the easy
default do that work without a mode.

## 11. Locations and equipment

- A location is a name plus an equipment profile. Profiles start from templates; the user is never asked
  to inventory their dumbbells.
- Location is chosen once per workout, defaulting to the last used or the detected one.
- A one-off "no equipment today" override exists for hotels and travel without creating a location.
- Continuity across locations comes from patterns: the plan tracks levels per exercise, but the rotation
  is written in patterns, so switching location swaps exercises without resetting anything. When a
  pattern's usual exercise is unavailable, the substitute's level comes from the user's history with that
  substitute, or a conservative estimate if there is none.
- Equipment decides how high a bodyweight progression goes. A vest, a dip belt or a loadable backpack adds
  loaded levels; without them the hardest variant is the ceiling.

## 12. Scheduling, automations and integrations

Three integrations exist, each off until the user turns it on and grants the permission, each used for
one thing:

- **Notifications.** One reminder a day at a chosen hour, with the same calm line every time. Never more.
- **Calendar.** Reads today inside the awake hours. A busy day shortens the default to twenty-five
  minutes, a heavy one also makes it easy, by two thresholds; a free slot is suggested; with auto-track on,
  a finished workout is written back. Its own section in Settings (`CALENDAR.md`).
- **Location.** Picks the nearest saved location when the app opens, if the user saved a position for it.

Scheduling is sequence-based. The rotation has no days attached. The calendar matters only for gentle
suggestions and for the gap detection that drives person state.

Automations observe context and change defaults. They never start a workout, log anything, or move a
level. An energy or time they default to does not count as the user's choice.

**Location triggers**
- Arrive at a known gym: notify that today's workout is ready.
- Leave a gym with nothing logged: one question, quick log?
- At home on a likely workout day: offer the home version.
- Away from all known locations for two or more days: switch to the no-equipment profile.

**Calendar triggers**
- Free block of thirty minutes or more: suggest that a workout fits there.
- Packed day: default time to short.
- Travel event: pre-switch the location profile.
- Person state is at risk: one nudge, never daily.
- Short picked on most weekdays: default time to short on weekdays.

## 13. What the user sees

- **Today.** How the user is and what that makes of today: the workout's name, one line of numbers, and a
  body map of what it works with two or three lines saying why and what has not been worked lately. The
  controls sit at the bottom where the thumb is: energy, time (minutes, or with the time limit off, how
  many exercises), move instead, and Plan it. Changing any of them rebuilds the workout in place.
- **Plan.** The workout in order, warm-up to stretching, each exercise with its level, sets and minutes,
  and a bar of the whole. A row shows a tag only when today differs from the usual: next level, 85 %, a
  version down; never an exercise's class. Reshuffle, swap, level, move, warm-up, cardio and stretching
  today, one at a time or circuit, and Start.
- **Words.** "Progression" and "level" are explained in plain words on first run, on every exercise card, and
  wherever a level can be edited: the progression is every step an exercise can get harder by, the level is the
  step you are on. No screen assumes the user knows the vocabulary. Movement patterns (squat, hinge, push,
  pull) are never a label on a row; they are one index the user can choose to browse by.
- **During.** The strip of the whole workout, the item under way marked lifting or resting; the current
  exercise, its level and its sets; a guide that says what to do now ("Go give it your best!", or "Rest up
  and let us know when you're ready" with the planned rest and what comes next); the lifting and rest so
  far. At the bottom one thing at a time: the reps while lifting, then I'm ready. A stop button that asks
  one thing: energy, time, pain, or no reason.
- **After.** The optional feel tap, then one line about what changed, such as "bench steps up next time",
  the time against the plan, and lifting and rest for the workout and each item.
- **Exercise card.** Level, average time per set, best total at this level, cost with override, and the
  step guide.
- **Progress.** Workouts per month over time. Level trend per exercise, grouped by the chosen index. The strain muscle map of current strain points, a strip per muscle, and the strain points timeline. Days active this month. Nothing
  that resets to zero.
- **Settings.** The settings of section 9, in plain words, with the reminder, the calendar and the
  locations each in a section of their own.

## 14. Non-goals

Explicitly out of scope, at least until the core loop has proven itself.

- Nutrition, body weight, and body composition.
- Social features, sharing, and leaderboards.
- Form coaching beyond the step guides, and video.
- Detailed analytics, heart rate, pace, routes, or any cardio metric beyond duration and effort.
- Program marketplaces or user-authored programs.
- Anything that asks the user to configure behaviour the app could infer.

## 15. Open questions

- **Section 8.7 is thin.** What the user sees between workouts is the strongest lever on adherence and
  the least defined part of this document.
- **The expression shares are guesses.** 85, 70 and 60 per cent of the level are the usual table; real
  days will say whether the light expression lands too heavy for beginners. The difficulty drift rules
  need to be watched for exercises that drop too fast.
- **Timing model seeds.** The seconds per set by cost are placeholders until a few workouts of real taps
  exist.
- **A weekly budget.** Whether to cap how many hard workouts land in a week, or trust the energy pick.
- **Bodyweight progressions.** Which variants belong on each progression, and where half-levels help.
- **Reminder tone.** The words matter as much as the timing. Needs real copy and testing on the primary
  user.

## 16. Feature notes

Each feature that reaches outside the app gets its own short note beside this file. The note says what the
feature is, what it reads, what it changes, and what it never does. This document stays the whole; the notes
stay lean.

- `CALENDAR.md`: the calendar as the shape of the day, planning a workout ahead of time, and the workout
  log written back.
- `LOCATION.md`: locations as places with equipment, the phone's position as a way to pick one, and
  distances between them.
- `EXERCISES.md`: what an exercise is, its levels and how-to, the library, and the indexes it can be browsed by.
- `WORKOUT.md`: filling the minutes, a level as strength and its expressions, intents and the energy
  dials, spare minutes, and judging against the working level.
- `MUSCLE_MAP.md`: the muscles, strain points from set, exercise and workout, their decay, the three shades,
  the strain points timeline, and how strain points choose between exercises.
- `IDEAS.md`: things worth keeping that are not being built now.
