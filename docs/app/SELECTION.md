# Selection

Selection decides what is in a workout: which muscles get worked today and which exercise works each one. It
starts from what the user said they care about, asks the muscle map whether each muscle is ready, takes the
muscles whose turn it is, and covers them with exercises the user likes. It never decides how many, how hard,
or how long; the builder does that (`WORKOUT.md`). There is no plan to follow and no list of workouts: every
visit is built from where the body is now and whose turn it is.

Everything here is worked out from the logged sets every time, never stored, so the figure, Progress, the
forecast and the picks can never disagree. The muscles are the map's own twenty (`MUSCLE_MAP.md`); the eleven
groups of the muscle index (`EXERCISES.md`) are for browsing the library only.

## What the user says

Three things, in their own words, and nothing else about muscles.

- **A tag per muscle**, standing, on the goal. *Active*: the user wants this muscle worked. It gets exercises
  of its own and is measured by direct work, a set where it is a main muscle. *Passive*: incidental work is
  fine. It never gets an exercise of its own, but it steers which exercise is chosen, and it is measured by
  any work, main or helper. *Ignored*: not considered at all. It may still help in an exercise; nobody counts.
- **How often**, per active muscle: less, usual or more. Half as often, as often, or twice as often as its turn
  would otherwise come round.
- **A word per exercise**: liked, fine, or not for me; unrated until they say.

Muscle choices and exercise choices never compete, because they answer different questions. Tags and how
often decide which muscles get places. The words decide which exercise fills a place. A love of curls never
earns the biceps an extra day.

The goal template sets the tags, and the user changes any of them. Get stronger marks the big movers active
(quads, hamstrings, glutes, chest, lats, upper back, front shoulders, abs) and the rest passive. Build muscle
adds the side and rear shoulders, biceps, triceps and calves. Stay fit adds the calves. Feel better keeps the
big movers only. The shins are ignored by every template. A muscle the user forces on the picker for a day
is active for that day whatever its tag.

## Whose turn it is

- **Readiness** comes first. A muscle is ready when it is strain-free (`MUSCLE_MAP.md`), counting today's plan
  so far. Ready muscles are taken before any that is carrying strain, whatever their turn. When no active
  muscle is ready, the least strained ones stay, and the plan says what is still carrying strain.
- **Overdue** decides the order among ready muscles. For an active muscle, *since* is how many strength
  workouts have finished since it was last a main muscle of an attempted exercise; a muscle never worked is as
  overdue as all the workouts so far. Overdue is since, doubled for more, halved for less. The most overdue
  goes first. Ties go to more often, then to the big movers (the selection order: quads, upper back, chest,
  hamstrings, lats, front shoulders, glutes, abs, ...).
- **Passive muscles** keep their own clock, *helped since*: workouts since any attempted exercise had them as a
  main or helper muscle. It never earns them a place; it ranks exercises.

This is a weighted round robin, and the count of active muscles is the cadence: twelve active muscles and
four exercises a workout means each comes round about every third workout, more or less often by the setting.
A strength template marks fewer muscles active, so its big lifts come round every workout or two. The robin
heals itself: whatever is skipped today is the most overdue tomorrow. Helper work never delays an active
muscle's turn, so a muscle the user wants worked is never buried by the presses that happen to touch it.

More often cannot beat recovery. A muscle worked for three sets carries strain for two days, so at three days
a week "every workout" is not reachable, and the forecast says what is.

## The engine

Selection works in two stages. First the **requirements**: the muscles today must work as a main muscle.
Then the **cover**: exercises whose primary muscles, between them, include every requirement. An exercise
does not have to be for one muscle; a squat meets quads and glutes at once. The goal says how many exercises
a workout holds (`WORKOUT.md`), and that number bounds the cover, not the requirements.

1. **Forced muscles** (today's picker) are requirements first, in the user's order, strained or not.
2. **Active muscles** join one at a time in turn order, for as long as the cover of every requirement still
   fits the exercise count. Each time a muscle joins, the cover is worked out again from the start, so a later
   muscle can turn an earlier pick into one exercise that works both.
3. **A muscle the cover already works** as a main muscle joins the requirements at no cost.
4. **Places still free** once no other muscle fits give the requirements a second exercise each, in turn
   order. Manual mode stops at step 1: the forced muscles, each covered once, and spare minutes go to sets.

The cover takes the requirements most important first. A requirement an exercise already chosen works as a
main muscle is met. Otherwise it gets the best exercise for it by the order below. A requirement nothing here
can cover is left uncovered, and the plan says so.

## Which exercise

For a requirement, the candidates are the strength exercises with that muscle among their primary muscles,
doable with the equipment here, not already in today's plan, not paused for pain, and with no excluded
muscle among their primary muscles (a forced muscle whose every candidate works an excluded one too takes
one of those rather than nothing). Power, stability, cardio and stretching entries are never picked for a
muscle. The order, each rule breaking only the ties the one above left:

1. **Ready.** Every primary muscle strain-free, counting today's plan so far. Then the lowest shade.
2. **Not for me** last, whatever follows.
3. **Covers the most** other requirements still waiting. Then works the fewest already met, so no muscle is
   worked twice in a day when that can be helped. Forcing lats and biceps gives one chin-up rather than a
   pulldown and a curl.
4. **Liked**, then fine and unrated together.
5. **Helps the most overdue passive muscle**, by helped since.
6. **A turn for something new.** When a turn is due, unrated ranks above fine for this one pick. A turn is
   due when the practised pick for this muscle has had its run in a row: one in eight, four or two
   appearances, by the setting. Never on a hard day, and only for the last place, so the user's main work is
   never the experiment.
7. **Practised** here beats never done. This is what keeps the same exercise coming back at each place: the
   gym has its row and home has its row, with nothing stored to say so.
8. **Library rank.** The last word. The library ranks the big lifts first for each muscle, so a fresh
   account gets a squat, a row and a bench before anything smaller.

Rule 3 sits above the user's word on purpose: the active list is a stronger statement than a like, and a
like is cheap (a manual pick makes one). The row says why: "also covers biceps, due". Not for me settles it
the other way.

The same order, with reasons, is the swap sheet for a place. Each alternative says what it brings: "also
covers biceps", "liked", "helps forearms", "new to you".

## Shuffling

Two seeds, kept with today's plan, so a draw is stable until the user starts or draws again.

- **Shuffle muscles.** A different combination of what is due. The pool is the ready active muscles in turn
  order, two workouts' worth; today's places are drawn from it, weighted toward the more overdue. A muscle not
  in the pool is never drawn in, a forced muscle never drops out, and the clocks make whatever was skipped the
  most overdue next time.
- **Shuffle exercises.** The same requirements, the cover run again with the seed in place of rules 7 and 8.
  Coverage holds by construction: a squat and a leg press both cover quads and glutes, so the seed can swap
  one for the other, while a leg extension ranks below both as long as the glutes are waiting. A shuffle may
  change the number of exercises, when a draw covers two requirements at once or stops doing so.
- **Swap one exercise** on its row, from the ordered alternatives. A swap that drops a requirement is
  repaired by the engine if a place is free, and flagged on the plan if not.

Draw again repeats the last shuffle with a new seed. Back restores the previous draw. Reset clears both.
Constraints, forced and skipped muscles, and the user's own swaps hold under any shuffle.

An exercise draw freezes the current requirements before rerunning the cover. Automatic requirements are
retained too, not just forced muscles. A muscle draw clears that frozen list and computes new requirements.
Hand-picked exercises keep their places before the remaining requirements are covered. Changing today's
muscle states or switching Manual clears the draw history; Back is for draws within the same constraints.
The controls try up to twelve seeds for a different result. An exercise draw is accepted only if it still
covers every previously covered requirement. If no different result fits, the current draw stays and the
UI says so. Time/energy limits and manual swaps can still leave requirements uncovered; that warning is
computed after fitting the final workout, including when the workout is empty.

## The forecast

The settings and Progress say what the rules will actually do, by running them: the next twelve strength
workouts from the user's state as it is, every set done, at the usual minutes and the usual location. Per
active muscle: about every N workouts, and the last time it was worked. Per passive muscle: which exercises
helped it. A warning where how often asks for more than recovery allows. One line sums it up: "Your twelve
active muscles come round about every three workouts." It updates as the user changes a tag.

The first simulated workout is now; later workouts are spaced evenly using Days a week. The forecast uses
the saved time-limit/count setting and warm-up. Passive evidence includes incidental primary work as well
as secondary work. "No help in the next twelve workouts here" describes this forecast, rather than claiming
the entire library has no suitable exercise. Recovery warnings report simulated turns withheld by strain.
The UI shows these assumptions, and the simulation never writes back to the real state.

## What it learns

- **The clocks.** Every logged set resets a muscle's clock: direct work for active muscles, any work for
  passive ones. Worked out from history every time, never stored.
- **A first-time exercise asks once.** After the workout, after the feel tap, one row per exercise that
  appeared for the first time: liked, fine, not for me. One tap each, skippable. Skipped stays unrated and
  comes round again on its turn.
- **Three swaps in a row ask.** An exercise swapped out three times in a row, never done in between, whatever
  its word, shows one line on the swap sheet: "You keep swapping this one out. Still like it?", with the three
  words to tap. Doing it once resets the count. A nudge, never a change.
- **A manual pick is a soft like.** An unrated exercise picked by hand counts as liked for four weeks unless
  rated. A rated one keeps its word.
- **A muscle forced by hand** three times in two weeks earns one line: mark it active, or more often if it
  already is. Never a change.

## Where it shows

- **Today:** the day's name from every muscle worked as a main muscle; the muscles panel, a small figure
  painted like the picker, saying what is worked, forced and excluded; each row's why in a sentence ("due,
  last worked four workouts ago · also covers biceps"); a line for any requirement left uncovered; the
  shuffle sheet.
- **The picker:** each tile's tag and clock ("active · due, last worked 5 workouts ago", "passive · helped by
  rows"). Ignored muscles start excluded, passive and active start by strain. Forcing any muscle makes it
  active today.
- **Settings → Goal, Muscles:** the figure painted by tag, a row per muscle with its tag, how often and the
  forecast, and the one-line summary.
- **Progress, Rhythm:** per active muscle, last worked and about every N; per passive muscle, helped by what.
- **The swap sheet:** the alternatives in selection's order, each with its reason.
- **After:** the one row per first-time exercise, and the line for a muscle forced three times.

## What it reads

- The logged sets of every workout, their intents, and when each workout ended.
- Each exercise's type, primary and secondary muscles, equipment, rank, and the user's word on it.
- Appearances per exercise, and swaps out in a row.
- The location's equipment and any pain pause.
- The goal's counts, tags and how often.

## What it never does

- Read energy, a level, a verdict, or the feel tap. Energy turns the dials after selection and never changes
  the list.
- Let a word choose a muscle. It only chooses the exercise for the muscle already chosen.
- Let a turn override readiness. Due and strained means wait, and the why-line says so.
- Count helper work toward an active muscle's turn.
- Let a shuffle reach a muscle that is not due, drop a forced one, or break the cover.
- Change a word or a tag on its own. Both come from the user; the app only asks.
- Ask anything per set, or more than one tap per question.

## Guardrails

- Less is half, never none. An active muscle not worked for twelve strength workouts gets one line on
  Progress, no nudge.
- A first appearance is never a push, and something new never lands on a hard day or on the first muscle.
- Every pick carries its why in one line a person would say.
- The forecast never promises what the engine will not deliver, because it is the engine.

## How it fits the rest

The muscle map (`MUSCLE_MAP.md`) answers readiness. The goal (`APPLICATION.md` section 6) sets the counts,
the tags and how often. The location (`LOCATION.md`) filters candidates. The builder (`WORKOUT.md`) takes the
list and fits, orders and dials it: muscles marked more often first, then hardest first, so strength gains
land where the user wants them. The progression (`APPLICATION.md` section 8) never hears from selection, and
selection never hears from it.

## Settings

| Setting | Default | Range | Where |
|---|---|---|---|
| Tag, per muscle | by the goal template | active, passive, ignored | Settings → Goal, Progress |
| How often, per active muscle | usual | less, usual, more | Settings → Goal, Progress |
| Try new exercises | rarely | rarely (one in 8), sometimes (one in 4), often (one in 2) | Settings → Goal |
| Preference, per exercise | unrated | liked, fine, not for me | the exercise card, the swap sheet, after a workout |

Fixed for now: the three swaps; the four weeks a soft like lasts; the two weeks and three forces for the tag
line; two workouts' worth for the muscle shuffle pool; twelve workouts for the forecast.

## Open questions

- Whether covering a second due muscle should beat a liked exercise (rule 3 above rule 4), or the other way.
- Whether the day's name should fold muscles back into groups ("Back day" for lats and upper back).
- Whether a soft like should last four weeks or fade with appearances.
- Whether the forecast should run at the location the user is at, or at every saved one.
