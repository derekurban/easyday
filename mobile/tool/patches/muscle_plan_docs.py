"""Docs for the muscle plan and the Today rework: SELECTION.md and APPLICATION.md, CRLF kept."""
import pathlib, sys

root = pathlib.Path(__file__).resolve().parents[3] / 'docs' / 'app'

def patch(name, pairs):
    p = root / name
    b = p.read_bytes()
    crlf = b'\r\n' in b
    s = b.decode('utf-8').replace('\r\n', '\n')
    for old, new in pairs:
        if old not in s:
            sys.exit(f'{name}: not found: {old[:60]!r}')
        s = s.replace(old, new, 1)
    if crlf:
        s = s.replace('\n', '\r\n')
    p.write_bytes(s.encode('utf-8'))

patch('SELECTION.md', [
    ("""A first appearance is never asked for the next level. A hard day's pushes go to practised exercises. A workout
is named for the first two muscles it works, "Quads and back".
""", """A first appearance is never asked for the next level. A hard day's pushes go to practised exercises. A workout
is named for every muscle group it works, in order, as a day: "Chest day", "Back and biceps day", "Back, triceps
and forearms day".
"""),
    ("""Everything above is a default. The user's pick always stands, for today.

- **Work a muscle.** On Today or the plan, pick any muscle group. It takes a place up to the goal's most, or
  the last place when the list is full, with the best exercise for it by the rules above. If the muscle is
  still carrying strain the plan says so and does it anyway.
""", """Everything above is a default. The user's pick always stands, for today.

- **The muscle plan.** Before the workout is built, every muscle group is in one of three states for today.
  *Excluded*: not worked, not even to fill spare minutes. *Available*: in the pool selection draws from by the
  rules above. *Forced*: worked for certain, by an exercise that has it as a primary muscle, taking a place
  before the rules fill the rest. The defaults come from the muscle map: a group whose most strained muscle is
  at any shade starts excluded (the threshold is one constant, `excludeFromShade`), the rest start available,
  nothing starts forced. The muscle picker on Today changes them: a tap on a muscle on the body cycles its
  group excluded, available, forced; a list view shows the groups under the three headings, each tile
  draggable up, down and between them, with its strain and its share beside it. Done rebuilds the workout.
  A forced group still carrying strain is worked anyway, and its why-line says so. When every group is
  excluded, or nothing here works the available ones, Today says so and offers the picker or a movement day.
"""),
    ("""- **Today:** two or three lines under the body map saying which muscles were chosen and why ("Back: ready and
  behind this week"), and what is still carrying strain. The control to work a muscle.
""", """- **Today:** the day's name, the muscles panel (a small figure painted like the picker: forced green, excluded
  red for strain or dim, available plain) saying what is worked, forced and excluded, and the picker behind it.
  Each exercise's why-line is on its sheet.
"""),
])

patch('APPLICATION.md', [
    ("""3. **It shows what that makes of today.** The workout the selection rules built for the current location:
   one line of numbers and a body map of what it works, with a line or two saying which muscles were chosen
   and why, and what is still carrying strain. Swapping to a movement workout, changing location, and asking
   for a muscle the plan did not pick happen here.
4. **Plan it.** The plan lays the workout out in order: the warm-up, each exercise with its level, sets and
   minutes, then cardio and stretching. One tap each to reshuffle, swap an exercise for another for the same
   muscle, edit today's level (or save it as the new level), move an exercise up or down, leave an exercise
   out today, pick the warm-up, leave out cardio or stretching today, and choose one at a time or circuit. Start starts the clock.
""", """3. **It shows what that makes of today.** The workout the selection rules built for the current location,
   named for the muscle groups it works ("Back and biceps day"), one line of numbers, and a muscles panel: a
   small body figure and what is worked, forced and excluded today. Tapping it opens the muscle picker
   (`SELECTION.md`, the muscle plan): every group excluded, available or forced, chosen on the body or in a
   list. Swapping to a movement workout and changing location happen here too.
4. **The plan is on Today.** Under the name, the workout in order: the warm-up, each exercise with its level,
   sets and minutes, then cardio and stretching. One tap each to reshuffle, swap an exercise for another for
   the same muscle, edit today's level (or save it as the new level), move an exercise up or down, leave an
   exercise out today, pick the warm-up, leave out cardio or stretching today, and choose one at a time or
   circuit. Start starts the clock. There is no separate plan screen.
"""),
    ("""- **Today.** How the user is and what that makes of today: one line of numbers, and a body map of what it
  works with two or three lines saying which muscles were chosen and why, and what is still carrying
  strain. A control to work a muscle the plan did not pick. The controls sit at the bottom where the thumb
  is: energy, time (minutes, or with the time limit off, how many exercises), move instead, and Plan it. Changing any of them rebuilds the workout in place.
- **Plan.** The workout in order, warm-up to stretching, each exercise with its level, sets and minutes,
  and a bar of the whole. A row shows a tag only when today differs from the usual: next level, 85 %, a
  version down; never an exercise's class. Reshuffle, swap, level, move, warm-up, cardio and stretching
  today, one at a time or circuit, and Start.
""", """- **Today.** The day's name from the muscles it works, one line of numbers, the muscles panel (tap for the
  muscle picker), then the workout in order, warm-up to stretching, each exercise with its level, sets and
  minutes, and a bar of the whole. A row shows a tag only when today differs from the usual: next level,
  85 %, a version down, forced; never an exercise's class. Tap a row to swap, change the level, move or leave
  it out. The controls sit at the bottom where the thumb is: energy, time (minutes, or with the time limit
  off, how many exercises), move instead, muscles, reshuffle, and Start. Changing any of them rebuilds the
  workout in place.
- **The muscle picker.** The body, front and back, with a stack of view tabs at the bottom right: both,
  front, back, list. A tap on a muscle cycles its group excluded, available, forced; the list has the groups
  under those three headings, draggable between them. A line above Done previews the day's name, count and
  minutes as the states change.
"""),
])
print('ok')
