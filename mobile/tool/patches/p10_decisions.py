import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

W = r'D:\Working\fitness\docs\app\WORKOUT.md'
patch(W, [
("""Every exercise has a working level: its level, its working set count (from the goal, three by default),
and the rep range for its cost and the goal (table below).""",
 """Every exercise has a working level: its level, its working set count (from the goal, three by default,
settable 2 to 5), and the rep range for its cost and the goal (table below). Sets stay inside that band
for good; progress is the level rising, never the sets. The extra set on a hard day is a one-off probe,
not a change to the band."""),
("""| Hard | 60 | extra on the costliest one, working on the rest, light past the budget | none |""",
 """| Hard | 60 | extra on the costliest one (a setting: one to five, or all), working on the rest, light past the budget | none |"""),
("""Which exercises get working or extra when the budget cannot cover all of them: the ones that have waited
longest for a working turn, ties by the goal's order. Over a rotation every exercise gets its turn.""",
 """Which exercises get the working turns when the budget cannot cover all of them: on easy, the ones whose
muscle groups are furthest behind (`COVERAGE.md`), at low cost, so an easy day is also a catch-up day; on
normal and hard, the ones that have waited longest for a working turn, ties by the goal's order, so over
a rotation every exercise gets its turn. With no history yet, both fall back to the goal's order. "All"
extras on hard means as many as the budget covers, costliest first; the rest go working, then light."""),
("""1. **The window** is the minutes picked, minus a five-minute warm-up, minus the cardio and stretching
   shares from the sliders in `COVERAGE.md`.""",
 """1. **The window** is the minutes picked, minus the cardio and stretching shares from the sliders in
   `COVERAGE.md`. There is no separate warm-up block yet (`IDEAS.md`); loaded exercises at cost 4 and 5
   carry their own warm-up sets."""),
("""   the highest-intent exercise that has room (light up to 3, working up to the working sets plus one on
   hard only), then the next; when every exercise is full and both have room, add one more pattern,
   chosen by coverage.""",
 """   the highest-intent exercise that has room (light up to 3; working stays at the working sets; extra is
   the working sets plus one), then the next; when every exercise is full and both have room, add one
   more pattern, chosen by coverage. Sets never go past the band; spare room becomes another exercise,
   then cardio."""),
("""Holds keep their own ranges in seconds. Bodyweight versions keep their floor, so a version is never asked
for fewer reps than make sense for it.""",
 """The template fills the three bands; each band is editable in the goal, as a range control, because
strength, muscle and fitness genuinely want different reps and some people know theirs. Holds keep their
own ranges in seconds. Bodyweight versions keep their floor, so a version is never asked for fewer reps
than make sense for it."""),
("""| Working sets | 3 | Settings → Goal |""",
 """| Working sets | 3 | Settings → Goal, 2 to 5 |
| Rep range per cost band | from the template | Settings → Goal, three range controls |
| Extras on a hard day | 1 | Settings → Goal, 1 to 5 or all |"""),
("""- Whether the working set count should rise on its own when a user keeps doing and hitting extra sets.
- Whether the budget should keep growing past an hour for users who genuinely train long.
- Whether easy's two working exercises should rotate like the working turns do, or always be the first two.""",
 """- How many workouts of history coverage needs before easy's catch-up picks beat the goal's order. Two
  is the guess."""),
])

A = r'D:\Washington' if False else r'D:\Working\fitness\docs\app\APPLICATION.md'
patch(A, [
("""   rest, light past the budget. Which exercises get the working turns: the ones that have waited longest.""",
 """   rest, light past the budget. The working turns go to the exercises furthest behind on coverage on easy,
   and to the ones that have waited longest on normal and hard. How many extras hard gives is a setting."""),
("""workout rather than nothing. They also appear inside lifting workouts as the warm-up and as the bonus
block.""",
 """workout rather than nothing. They also appear inside lifting workouts as the cardio and stretching
shares at the end (`COVERAGE.md`). A configurable warm-up and cool-down is in `IDEAS.md`."""),
("""| The goal: what to cover in order, reps-by-cost table, movement days | from the template | any order; any of the three tables |""",
 """| The goal: what to cover in order, rep range per cost band, movement days | from the template | any order; any sensible ranges |
| Extras on a hard day | 1 | 1 to 5, or all |"""),
("""- **Working sets.** Fixed by the goal for now. Whether the count should rise on its own when a user keeps
  doing and hitting extra sets.
""", ""),
("""- `COVERAGE.md`: which muscle groups recent sets have worked, the goal's emphasis, how the gap chooses
  between exercises, and the cardio and stretching shares.""",
 """- `COVERAGE.md`: which muscle groups recent sets have worked, the goal's emphasis, how the gap chooses
  between exercises, and the cardio and stretching shares.
- `IDEAS.md`: things worth keeping that are not being built now."""),
])

C = r'D:\Working\fitness\docs\app\COVERAGE.md'
patch(C, [
("""- **Which pattern gets an extra slot.**""",
 """- **Which exercises do the work on an easy day.** Easy gives two exercises a working turn; they are the
  two whose primary groups have the largest deficit, among those at cost 3 or under. An easy day is a
  catch-up day for whatever has been missed, at low cost.
- **Which pattern gets an extra slot.**"""),
("""A 60-minute workout at the defaults is 5 minutes of warm-up, 36 of lifting, 9 of cardio and 6 of
stretching.""",
 """A 60-minute workout at the defaults is 45 minutes of lifting, 9 of cardio and 6 of stretching."""),
("""- Whether cardio should credit the lower body a little, so a runner's plan tilts toward upper work.
- Whether stretching should follow coverage too: the routine picked by which groups were worked today.
- Whether a large deficit should ever add a pattern the goal does not list, or only choose among what it
  does.
- Whether the window should be time-based (two weeks) for users whose rotation is long.""",
 """- How many workouts of history are enough before the deficit is trusted over the goal's order.
- The rest are in `IDEAS.md`: cardio crediting legs, stretching following coverage, a deficit adding a
  pattern, a time-based window."""),
])

E = r'D:\Working\fitness\docs\app\EXERCISES.md'
patch(E, [
("""- **A cost, 1 to 5.** How much one hard set takes out of the whole body. Derived from the exercise: how
  much muscle moves (1 to 3), plus one if the load goes through the spine or the body hangs from the arms,
  plus one if the load can get heavy relative to bodyweight. The energy budget is spent in it, and the rep
  range follows it. It can be overridden.""",
 """- **A cost, 1 to 5.** How much one hard set takes out of the whole body. The rubric: how much muscle
  moves (1 to 3), plus one if the load goes through the spine or the body hangs from the arms, plus one if
  the load can get heavy relative to bodyweight. The library carries the number; the three parts are a
  mechanism the rows can be tagged with later (`IDEAS.md`). The energy budget is spent in cost, and the
  rep range follows it. It can be overridden."""),
("""- Half levels: a pause or tempo step between two versions when the jump is large. The data allows it; the
  library mostly does not use it yet.
- Muscles and visuals: step guides with pictures are a later layer on top of the how-to text, not a
  replacement for it.
- User-made exercises and user-made indexes: both are shaped for, neither is built. Revisit once the library
  and the indexes have been used for a while.""",
 """- Half levels, step guides, user-made exercises and indexes, sharing: all in `IDEAS.md`."""),
])

L = r'D:\Working\fitness\docs\app\LOCATION.md'
patch(L, [
("""- Whether a location with no saved position should offer to save one the first time a workout starts there.
- Whether the most used location should be counted over all time or the last few weeks.""",
 """- Whether the most used location should be counted over all time or the last few weeks.
- The rest are in `IDEAS.md`."""),
])

M = r'C:\Users\derek\.claude\projects\D--Working-fitness\memory\fitness-app-intent.md'
patch(M, [
("chooses between candidate exercises (COVERAGE.md). See docs/app/WORKOUT.md.",
 "chooses between candidate exercises (COVERAGE.md). Decisions 2026-10-15: sets stay in a band (2-5), only the level\nrises; easy's working turns go to under-covered muscles at low cost; hard extras is a setting (1-5/all, default 1);\nrep ranges per cost band stay editable in the goal; no warm-up block (IDEAS.md). See docs/app/WORKOUT.md, IDEAS.md."),
])
print('ok')
