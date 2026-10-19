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
- **Share.** Should this muscle work today. The sets a muscle group has had over the look-back, against the
  target the goal sets for it, scaled by its emphasis. Three bands: behind, on track, done.
- **Preference.** Which exercise, once the muscle is chosen. Liked, fine or not for me, the user's own word on
  each exercise; unrated until they say.

Readiness answers "can", share answers "should", preference answers "which". They are asked in that order,
and a later answer never overrides an earlier one: a liked exercise never pulls in a strained muscle, and a
muscle that is behind never jumps the queue past one that is ready.

## Share

- **Counting.** A working set gives one to the group of each primary muscle and a half to the group of each
  secondary one. A light set gives half of that, as strain points do. Sets attempted count; sets planned and
  never started do not.
- **The look-back.** The last seven days, today included, by calendar days like the rest of the app. A setting,
  3 to 14 days.
- **The target.** Sets per muscle group over the look-back, one number for every group, seeded from days per
  week: 6 for two days, 8 for three, 10 for four or more. A setting, 2 to 30. Ten sets a week per muscle is
  where the research puts a good return for growth; strength flattens earlier.
- **Emphasis.** Less, usual or more, per group: half, one, and one and a half times the target. "More back"
  keeps the back behind for longer, so it is picked more often, goes earlier in the workout and takes spare
  minutes first. It is never achieved by cramming: strain still caps a muscle at full in one day. More comes
  from frequency and priority across the look-back, which is what the volume and order research supports.
- **The bands.** Behind is under half the target. On track is half to just under it. Done is the target or
  more. Done is the lowest priority, never a cap: a muscle that has had its share still works when nothing
  else is ready and behind.

The groups are the eleven of the muscle index (`EXERCISES.md`): chest, back, shoulders, biceps, triceps,
forearms, core, glutes, quads, hamstrings, calves.

## Which muscles

The goal says how many exercises a workout holds (`WORKOUT.md`). Selection fills that many, one muscle each,
by these rules in order. A later rule only breaks ties left by an earlier one.

1. **Ready.** Strain-free muscles first. A muscle paused for pain is left out.
2. **Behind.** The lowest band first: behind, then on track, then done.
3. **Emphasis.** More, then usual, then less.
4. **Furthest behind.** The most sets short of its target.
5. **Longest waiting.** The muscle worked longest ago.

One exercise per muscle: a muscle takes a second exercise only when every other ready muscle that is behind
already has one. Every pick is added to today's plan before the next is chosen, so its strain points count:
once bench is in, chest and front shoulders carry today's work and a fresh muscle wins the next place.

When no muscle is ready, the least strained ones stay, and the plan says what is still carrying strain.

**Spare minutes** that go to more exercises take the next muscle by the same rules, up to the goal's most.

## Which exercise

For each chosen muscle, the candidates are the exercises with that muscle as a primary, doable with the
equipment here, not already in today's plan and not paused for pain. The rules, again in order:

1. **Ready.** Every primary muscle strain-free, counting today's plan so far. Then the lowest shade.
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
is named for the first two muscles it works, "Quads and back".

## The user's own picks

Everything above is a default. The user's pick always stands, for today.

- **Work a muscle.** On Today or the plan, pick any muscle group. It takes a place up to the goal's most, or
  the last place when the list is full, with the best exercise for it by the rules above. If the muscle is
  still carrying strain the plan says so and does it anyway.
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

- **Today:** two or three lines under the body map saying which muscles were chosen and why ("Back: ready and
  behind this week"), and what is still carrying strain. The control to work a muscle.
- **The plan:** a row's tag when it is not for me, with leave it out today; the swap sheet in selection's
  order.
- **After:** the one row per first-time exercise, after the feel tap.
- **Progress:** the share strip: the eleven groups, sets over the look-back against each one's target, the
  emphasis word beside each, tappable to change it.
- **The exercise card:** the preference word.
- **Settings → Goal:** the look-back, the sets target, emphasis per group, how often to try something new.

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

- Less is half, never none. A group with no sets for two look-backs gets one line on Progress, no nudge.
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
| Sets per muscle group over the look-back | 6, 8 or 10, by days per week | 2 to 30 | Settings → Goal |
| Emphasis, per muscle group | usual | less, usual, more | Settings → Goal, Progress |
| Try new exercises | rarely | rarely (one in 8), sometimes (one in 4), often (one in 2) | Settings → Goal |
| Preference, per exercise | unrated | liked, fine, not for me | the exercise card, the swap sheet, after a workout |

Fixed for now: primary one and secondary a half; light sets half; behind under half the target; the three
swaps; the four weeks a soft like lasts; the two weeks and three picks for the emphasis line.

## Open questions

- Whether one exercise per muscle is too strict on a day the user built by hand.
- Whether a group's target should come from capacity instead of a setting (`IDEAS.md`).
- Whether an exercise that pays off more behind muscles should beat library rank. Tried and dropped: it made a
  sumo deadlift the first quads pick over the barbell squat.
- Whether a soft like should last four weeks or fade with appearances.
