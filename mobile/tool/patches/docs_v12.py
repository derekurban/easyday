import os
root = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'docs', 'app')

def patch(name, pairs):
    p = os.path.join(root, name)
    s = open(p, encoding='utf-8').read()
    for old, new in pairs:
        assert old in s, (name, old[:70])
        s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)

patch('WORKOUT.md', [
("""- **Time is filled, always.** Every set has a price in seconds. The builder fits the listed exercises, then
  spends what is left as the goal says: more exercises up to the goal's most-exercises number, cardio, or
  rest.""", """- **Time is filled, always.** Every set has a price in seconds. The builder fits the listed exercises by the
  goal's three calibrations (below), then spends what is left as the goal says: more exercises, cardio, or
  rest.
- **Three calibrations, not three caps.** The exercises in a workout, the working sets, and the exercises
  pushed on a hard day are each a band of three numbers: the fewest, the ideal, the most. The ideal is the
  sweet spot. A tight day falls toward the fewest and never below it unless the minutes cannot hold even
  that. A long day, one where the ideal list fills no more than half the window, or a hard day, grows toward
  the most. Nothing else ever reaches the most."""),
("""The goal holds a rep band per difficulty, hard, medium and easy, and that is the whole program. The named
programs are presets for the three rows: Strength is heavy on hard lifts, middle on medium, light on easy;
Build is middle, middle, light; Endurance is light everywhere; Mixed is Strength with the hard row holding
two bands, heavy then middle, which cycle by workout, A and C heavy, B and D middle. Any band can be edited
to any numbers, and any row can hold up to three bands to cycle. Any exercise can be set to its own band on
its card, for the lifter who wants seven on the bench and many on the calves whatever the program says. The
weight share follows the band from the same table, so a custom band lands at a sensible weight. Hitting the top of the range in any expression""",
"""The goal holds a list of rep ranges, up to six, each tagged with the difficulties it applies to: hard,
medium, easy, any mix. That list is the whole program. The ranges tagged with a difficulty, in list order,
are what its exercises train in, and when there is more than one they cycle by workout, A, B, C. A
difficulty with no range of its own borrows the nearest one's. The named programs are suggestions that fill
the list: Strength is heavy tagged hard, middle tagged medium, light tagged easy; Build is middle tagged hard
and medium, light tagged easy; Endurance is one light range tagged all three; Mixed is Strength with the
middle range also tagged hard, so hard lifts alternate heavy and middle, A and C heavy, B and D middle. Any
range can be edited to any numbers and retagged in its sheet. Any exercise can be set to its own range on
its card, for the lifter who wants seven on the bench and many on the calves whatever the list says. The
weight share follows the range from the same table, so a custom range lands at a sensible weight. Hitting the top of the range in any expression"""),
("""Every exercise has a working level: its level, its working set count (from the goal, three by default,
settable 2 to 5), and the rep range of its expression. Sets stay inside that band for good; progress is
the level rising, never the sets.""", """Every exercise has a working level: its level, its working set count (the goal's ideal sets, three by
default), and the rep range of its expression. Sets stay inside that band for good; progress is the level
rising, never the sets. On a tight day the sets may fall toward the goal's fewest, and those sets still
count; on a long or hard day sets may grow toward the most, and only the usual ones are judged."""),
("""| Hard | the next level on the hardest two (a setting: one to five, or all), working on the rest |""",
"""| Hard | the next level on the hardest few, working on the rest; room to grow toward the most sets and exercises |"""),
("""No budgets, no points. The same list at every energy; only the dials move. A hard day takes the same sets
and the same minutes as a normal one, one step heavier, so it always fits.""", """No budgets, no points. Easy and normal share one list; hard holds everything normal does and may add to
it. How many exercises a hard day pushes is the third calibration: the fewest on a tight day, the ideal on a
usual one, the most on a long one, hardest exercises first. A hard day takes the same minutes as a normal
one, one step heavier, so it always fits; with spare minutes set to more exercises it also grows toward the
most sets, then the most exercises, like a long day."""),
("""4. **Fit the minutes at normal.** Working sets everywhere. Over: the last exercise on the list goes, then
   the one that is left shrinks. Patterns dropped here come back first if room appears.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest. Then turn the dials for
   the energy picked, on that list; a hard day's push may take a set from a spare-minute exercise.""",
"""4. **Fit the minutes at normal.** The ideal sets everywhere. Over: exercises go down to the fewest, light
   ones first, then the last on the list; then sets come down to the fewest, the exercise with the most sets
   first; only when even that does not fit, below the fewest. Patterns dropped here come back first if room
   appears. A day that had to cut is tight; one where the ideal list fills no more than half the window is
   long.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest. More exercises grows the
   list back to the ideal; on a long day or a hard day it then grows sets toward the most, round the list
   one set at a time, then exercises toward the most. Then turn the dials for the energy picked, on that
   list. Easy never grows past the ideal."""),
("""| Working sets | 3 | Settings → Goal, 2 to 5 |
| Reps per difficulty | from the template: Strength, Build, Endurance, Mixed, or edited; up to three bands per row cycle by workout | Settings → Goal |
| Reps, per exercise | the goal's band for its difficulty | the exercise card |
| Most exercises in a workout | 4 | Settings → Goal, 1 to 10 |
| Hard day: next level on | 2 | Settings → Goal, 1 to 5 or all |""",
"""| Working sets: fewest, ideal, most | 2, 3, 4 | Settings → Goal, 1 to 6 |
| Rep ranges, each tagged by difficulty | filled from a program: Strength, Build, Endurance, Mixed; up to six, those sharing a tag cycle by workout | Settings → Goal |
| Reps, per exercise | the goal's range for its difficulty | the exercise card |
| Different exercises: fewest, ideal, most | 2, 4, 6 | Settings → Goal, 1 to 10 |
| Hard day, next level on: tight, usual, long | 1, 2, 3 | Settings → Goal, 0 to 10 |"""),
])

patch('APPLICATION.md', [
("""- **Goal.** One pick from a short list of templates, each stating what it means in practice: what a
  workout covers and in what order, the reps it likes, and how often a movement day comes round. Any knob can be
  changed right there, or later in settings. The same goes for locations: a template, then tick what is
  actually there.""", """- **Goal.** The user's own, named and shaped in plain words. Templates are suggestions that fill every
  knob at a tap: what a workout covers, the reps it likes, how many exercises and sets, how often a
  movement day comes round. Any knob can be changed right there, or later in settings. The same goes for
  locations: name it, tick what is there, or fill it from a template first."""),
("""- **Locations.** At least one, chosen from equipment templates such as "commercial gym", "home with
  dumbbells and a bench", or "nothing". Tweaks come later, if ever.""", """- **Locations.** At least one, the user's own: a name and an equipment list, filled from a template such
  as "commercial gym", "home with dumbbells and a bench", or "nothing" if that helps."""),
("""| The goal: what to cover in order, rep bands per difficulty, movement days | from the template | any order; any bands, up to three per difficulty cycling by workout |
| Most exercises in a workout | 4 | 1 to 10 |
| Reps per exercise | the goal's band for its difficulty | any band |
| Hard day: next level on | 2 | 1 to 5, or all |
| Spare minutes go to | more exercises | more exercises, cardio, rest |
| Working sets | 3 | 2 to 5 |""", """| The goal: what to cover in order, rep ranges tagged by difficulty, movement days | filled from a template | any order; up to six ranges, those sharing a tag cycling by workout |
| Different exercises in a workout: fewest, ideal, most | 2, 4, 6 | 1 to 10 |
| Reps per exercise | the goal's range for its difficulty | any range |
| Hard day, next level on: tight, usual, long | 1, 2, 3 | 0 to 10 |
| Spare minutes go to | more exercises | more exercises, cardio, rest |
| Working sets: fewest, ideal, most | 2, 3, 4 | 1 to 6 |"""),
("""| Index the library is grouped by | muscle group | muscle group, body region, movement pattern, equipment, progression type, difficulty |""",
"""| Index the library is grouped by | muscle group | muscle group, body region, movement pattern, equipment, progression type, difficulty |
| Reminder, calendar, position | each off | their own sections; `CALENDAR.md` and `LOCATION.md` list theirs |"""),
("""- **Calendar.** Reads only how busy today is. Six or more hours of events make the default twenty-five
  minutes.""", """- **Calendar.** Reads today inside the awake hours. A busy day shortens the default to twenty-five
  minutes, a heavy one also makes it easy, by two thresholds; a free slot is suggested; with auto-track on,
  a finished workout is written back. Its own section in Settings (`CALENDAR.md`)."""),
("""- **Settings.** The six settings of section 9, in plain words.""", """- **Settings.** The settings of section 9, in plain words, with the reminder, the calendar and the
  locations each in a section of their own."""),
])

patch('CALENDAR.md', [
("""## Settings

| Setting | Default | Range |""", """## Built so far

As of 0.12.0: the switch, the awake hours, the busy-day adjustment with both thresholds, the readout of
today with "last synced" and sync now, the suggested slot on Today with its advisory, auto-track with the
calendar to write to. The app reads on open and when asked, never on a timer. Planning a slot ahead of time,
the declinable event and the two-way sync wait on the planning flow (`IDEAS.md`).

## Settings

| Setting | Default | Range |"""),
("""| Plan a slot on or off | off | |""", """| Plan a slot on or off | off | not built yet |"""),
])

patch('LOCATION.md', [
("""- **Saved locations.** Named places with an equipment list, made from a template (commercial gym, home with
  dumbbells and a bench, hotel gym, nothing) and then ticked to match what is really there.""", """- **Saved locations.** Named places with an equipment list, the user's own, filled from a template if that
  helps (commercial gym, home with dumbbells and a bench, hotel gym, nothing) and ticked to match what is
  really there."""),
("""- Settings → Locations: each location, its equipment count, "position saved" or "anywhere", and the refresh
  with distances. Inside a location: save or update its position, or mark it anywhere.
- Settings → Integrations: the switch.""", """- Settings → Locations: each location, its equipment count, "position saved" or "anywhere", the refresh
  with distances, and the position switch. Inside a location: save or update its position, or make it
  anywhere."""),
("""| Position on or off | off | Settings → Integrations |""", """| Position on or off | off | Settings → Locations |"""),
])

patch('EXERCISES.md', [
("""- **Reps override.** A rep band for this exercise regardless of the goal's rows, if the user set it.""",
"""- **Reps override.** A rep range for this exercise regardless of the goal's list, if the user set it."""),
])

patch('IDEAS.md', [
("""## Location and calendar
""", """## Location and calendar

- **Planning a slot.** The planning flow of `CALENDAR.md`: pick a day and slot, a location, preview the
  workout, write a declinable event, sync both ways. The settings around it (awake hours, thresholds,
  auto-track) are built; the flow itself is not.
- **Rotation items that differ in length,** so Workout A can hold five exercises and B four. The
  calibration's ideal is one number for every item today.
"""),
])
print('docs ok')
