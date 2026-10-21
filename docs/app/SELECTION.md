# Selection

Selection decides what is in a workout: which muscles get worked today and which exercise works each one. It
asks two questions of history, is this muscle ready and has it had its share, and one of the user, which
exercises they like. It never decides how many, how hard, or how long; the builder does that (`WORKOUT.md`).
There is no plan to follow and no list of workouts: every visit is built from where the body is now.

## What it is

Two ledgers per muscle and one word per exercise. The ledgers are worked out from logged sets every time,
never stored; the word is the user's own.

- **Readiness.** Can this muscle work today. A muscle is ready when it is strain-free (`MUSCLE_MAP.md`). A
  muscle carrying strain waits.
- **Share.** Should this muscle work today. The sets a muscle has had over the look-back, against the
  target the goal sets for it, scaled by its emphasis. Three bands: behind, on track, done.
- **Preference.** Which exercise, once the muscle is chosen. Liked, fine or not for me, the user's own word on
  each exercise; unrated until they say.

Readiness answers "can", share answers "should", preference answers "which". They are asked in that order,
and a later answer never overrides an earlier one: a liked exercise never pulls in a strained muscle, and a
muscle that is behind never jumps the queue past one that is ready.

## Share

- **Counting.** A working set gives one to each primary muscle and a half to each secondary one. A light set gives half of that, as strain points do. Sets attempted count; sets planned and
  never started do not.
- **The look-back.** The last seven days, today included, by calendar days like the rest of the app. A setting,
  3 to 14 days.
- **The target.** Sets per muscle over the look-back, one number for every muscle, seeded from days per
  week: 6 for two days, 8 for three, 10 for four or more. A setting, 2 to 30. Ten sets a week per muscle is
  where the research puts a good return for growth; strength flattens earlier.
- **Emphasis.** Less, usual or more, per muscle: half, one, and one and a half times the target. "More lats"
  keeps the lats behind for longer, so it is picked more often, goes earlier in the workout and takes spare
  minutes first. It is never achieved by cramming: strain still caps a muscle at full in one day. More comes
  from frequency and priority across the look-back, which is what the volume and order research supports.
- **The bands.** Behind is under half the target. On track is half to just under it. Done is the target or
  more. Done is the lowest priority, never a cap: a muscle that has had its share still works when nothing
  else is ready and behind.

The muscles are the map's own twenty (`MUSCLE_MAP.md`): chest; front, side and rear shoulders; biceps,
triceps, forearms; abs, obliques; traps, lats, upper back, lower back; glutes, outer hips, inner thighs, quads,
hamstrings, calves, shins. Selection, the share ledger, emphasis and the muscle picker all
run on these, so what the user taps on the body is what the ledgers count. The eleven groups of the muscle
index (`EXERCISES.md`) are for browsing the library only. Saved emphasis from before, which was per group,
spreads to each of the group's muscles. The candidates are the library's strength exercises; power,
stability, cardio and stretching entries are never picked for a muscle.

Small muscles that compound lifts barely reach as a helper (outer hips, side shoulders) start furthest
behind, so with nothing else to separate them they come up early and often. Emphasis less on them, or a
target scaled by size, is the knob if that is too much (open questions).

## The engine

Selection works in two stages. First it settles the **requirements**: the muscles today must work as a main
muscle. Then it finds the **cover**: exercises whose primary muscles, between them, include every requirement.
An exercise does not have to be for one muscle; a squat meets quads and glutes at once. The goal says how many
exercises a workout holds (`WORKOUT.md`), and that number bounds the cover, not the requirements.

1. **Forced muscles** are requirements first, in the user's order, strained or not.
2. **Available muscles** join one at a time by the rules below, re-ranked against the cover so far, for as long
   as the cover of every requirement still fits the exercise count. Each time a muscle joins, the cover is
   worked out again from the start, so a later muscle can turn an earlier pick into one exercise that works
   both.
3. **A muscle the cover already works** as a main muscle joins the requirements at no cost.
4. **Places still free** once no other muscle fits give the requirements a second exercise each, in the same
   order. Manual stops at step 1: the forced muscles, each covered once, and spare minutes go to sets.

The cover itself takes the requirements most important first. A requirement an exercise already chosen works
as a main muscle is met. Otherwise it gets the best exercise for it by the rules under "Which exercise", with
two more in the middle: the exercise that works the most requirements still waiting wins, then the one that
works the fewest already met, so no muscle is worked twice in a day when that can be helped. Forcing lats and
biceps gives one chin-up rather than a pulldown and a curl.

Draw again sets a seed: available muscles are drawn at random among the ready ones instead of by share, and
exercises at random in place of practised and library rank. The same seed always draws the same workout.

## Which muscles

The available muscles join the requirements by these rules in order. A later rule only breaks ties left by an
earlier one.

1. **Ready.** Strain-free muscles first. A muscle paused for pain is left out.
2. **Behind.** The lowest band first: behind, then on track, then done.
3. **Emphasis.** More, then usual, then less.
4. **Furthest behind.** The most sets short of its target.
5. **Longest waiting.** The muscle worked longest ago.

One exercise per muscle: a muscle takes a second exercise only when no other muscle fits. Every pick is added to today's plan before the next is chosen, so its strain points count:
once bench is in, chest and front shoulders carry today's work and a fresh muscle wins the next place.

When no muscle is ready, the least strained ones stay, and the plan says what is still carrying strain.

**Spare minutes** that go to more exercises take the next muscle by the same rules, up to the goal's most.

## Which exercise

For each chosen muscle, the candidates are the exercises with that muscle as a primary, doable with the
equipment here, not already in today's plan and not paused for pain. The rules, again in order:

1. **Ready.** Every primary muscle strain-free, counting today's plan so far. Then, in a cover, not for me
   last, the most requirements still waiting, and the fewest already met. Then the lowest shade.
2. **Preferred.** Liked, then fine and unrated together, then not for me.
3. **A turn for something new.** When a turn is due, unrated ranks above fine for this one pick. A turn is
   due when the practised pick for this muscle has had its run in a row: one in eight, four or two
   appearances, by the setting. Never on a hard day, and only for the last muscle chosen, so the user's main
   work is never the experiment. When everything here is rated there is nothing to try.
4. **Practised.** Done here before beats never done. This is what keeps the same exercise coming back at each
   place: the gym has its row and home has its row, with nothing stored to say so.
5. **Library rank.** The last word. The library ranks the big lifts first for each muscle, so a fresh account
   gets a squat, a row and a bench before anything smaller.

**Not for me** fills a place only when nothing above it is ready and available here. The row says so, and one
tap leaves it out today; the exercise count drops by one rather than swapping. The user decides on the day
whether to do something they dislike.

A first appearance is never asked for the next level. A hard day's pushes go to practised exercises. A workout
is named for every muscle its exercises work as a main muscle, in order, as a day: "Quads, glutes, upper back
and chest day" for a squat, a row and a bench. Long names are known and left for later. Each row on Today says
every main muscle its exercise works.

## The user's own picks

Everything above is a default. The user's pick always stands, for today.

- **The muscle plan.** Before the workout is built, every muscle is in one of three states for today.
  *Excluded*: never takes a place, not even to fill spare minutes, and no exercise works it as a primary
  muscle (a forced muscle whose every exercise works an excluded one too still gets one). *Available*: in the pool selection draws from by the
  rules above. *Forced*: worked for certain, by an exercise that has it as a primary muscle, taking a place
  before the rules fill the rest. The defaults come from the muscle map: a muscle at any shade starts excluded (the threshold is one constant, `excludeFromShade`), the rest start available,
  nothing starts forced. The muscle picker on Today changes them: tap muscles on the body to select them
  (blue), then one of three pills says what the selected ones are today. A list view shows the muscles under
  the three headings, each tile draggable up, down and between them, with its strain and its share beside it.
  The figure shows the result like a muscle map: forced muscles in the primary green, the available muscles
  the workout chose in the secondary green, the other available ones plain, excluded ones very dark.
  *Shuffle* (the default) fills the places after the forced muscles from the available pool by the rules
  above, and Draw again takes ready muscles at random instead of by share; *Manual* works the forced muscles
  only, an exercise that works several of them counting for each. Done rebuilds the workout. A forced muscle still carrying strain is worked anyway, and its why-line
  says so. When every muscle is excluded, or nothing here works the available ones, Today says so and offers
  the picker or a movement day.
- **Swap.** The swap sheet lists every other exercise for the same muscle available here, in the order above,
  not for me under its own heading. Nothing a user picks changes its word.
- **Leave it out today.** On any row. The count drops by one.
- **Emphasis and preference** are the standing settings, in Settings → Goal and on the exercise card.

## What it learns

- **The ledgers.** Every logged set feeds readiness and share. Both are worked out from history every time,
  never stored, so the figure, the Progress strip and the picks can never disagree.
- **A first-time exercise asks once.** After the workout, after the feel tap, one row per exercise that
  appeared for the first time: liked, fine, not for me. One tap each, skippable. Skipped stays unrated and
  comes round again on its turn.
- **Three swaps in a row ask.** An exercise swapped out three times in a row, never done in between, whatever
  its word, shows one line on the swap sheet: "You keep swapping this one out. Still like it?", with the three
  words to tap. Doing it once resets the count. A nudge, never a change.
- **A manual pick is a soft like.** An unrated exercise picked by hand counts as liked for four weeks unless
  rated. A rated one keeps its word.
- **A muscle picked by hand** three times in two weeks earns one line suggesting more emphasis for it. Never a
  change.

## Where it shows

- **Today:** the day's name, the muscles panel (a small figure painted like the picker: forced primary green,
  chosen secondary, excluded dark, available plain) saying what is worked, forced and excluded, and the picker
  behind it.
  Each exercise's why-line is on its sheet.
- **The plan:** a row's tag when it is not for me, with leave it out today; the swap sheet in selection's
  order.
- **After:** the one row per first-time exercise, after the feel tap.
- **Progress:** the share strip: the nineteen muscles, sets over the look-back against each one's target, the
  emphasis word beside each, tappable to change it.
- **The exercise card:** the preference word.
- **Settings → Goal:** the look-back, the sets target, emphasis per muscle, how often to try something new.

## What it reads

- The logged sets of every workout, their intents, and when each workout ended.
- Each exercise's primary and secondary muscles, equipment, rank, and the user's word on it.
- Appearances per exercise, and swaps out in a row.
- The location's equipment and any pain pause.
- The goal's counts, look-back, target and emphasis.

## What it never does

- Read energy, a level, a verdict, or the feel tap. Energy turns the dials after selection and never changes
  the list.
- Let preference choose a muscle. It only chooses the exercise for the muscle already chosen.
- Let share override readiness. Behind and strained means wait, and the why-line says so.
- Pull a muscle past full in one day, or add a set to chase a share.
- Change a word on its own. Ratings come from the user; the app only asks.
- Ask anything per set, or more than one tap per question.

## Guardrails

- Less is half, never none. A muscle with no sets for two look-backs gets one line on Progress, no nudge.
- Done is never a cap.
- A first appearance is never a push, and something new never lands on a hard day or on the first muscle.
- Every pick carries its why in one line, built from the two ledgers and the word.

## How it fits the rest

The muscle map (`MUSCLE_MAP.md`) answers readiness. The goal (`APPLICATION.md` section 6) sets the counts, the
look-back, the target and the emphasis. The location (`LOCATION.md`) filters candidates. The builder
(`WORKOUT.md`) takes the list and fits, orders and dials it: emphasised muscles first, then hardest first, so
strength gains land where the user wants them. The progression (`APPLICATION.md` section 8) never hears from
selection, and selection never hears from it.

## Settings

| Setting | Default | Range | Where |
|---|---|---|---|
| Look-back | 7 days | 3 to 14 | Settings → Goal |
| Sets per muscle over the look-back | 6, 8 or 10, by days per week | 2 to 30 | Settings → Goal |
| Emphasis, per muscle | usual | less, usual, more | Settings → Goal, Progress |
| Try new exercises | rarely | rarely (one in 8), sometimes (one in 4), often (one in 2) | Settings → Goal |
| Preference, per exercise | unrated | liked, fine, not for me | the exercise card, the swap sheet, after a workout |

Fixed for now: primary one and secondary a half; light sets half; behind under half the target; the three
swaps; the four weeks a soft like lasts; the two weeks and three picks for the emphasis line.

## Open questions

- Whether one exercise per muscle is too strict on a day the user built by hand.
- Whether a muscle's target should come from capacity instead of a setting (`IDEAS.md`), or be scaled by its
  size, so the small muscles stop coming up as often as the big ones.
- Whether the day's name should fold muscles back into groups ("Back day" for lats and upper back).
- Whether an exercise that pays off more behind muscles should beat library rank. Tried and dropped: it made a
  sumo deadlift the first quads pick over the barbell squat.
- Whether a soft like should last four weeks or fade with appearances.
