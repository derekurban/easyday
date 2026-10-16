import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

C = r'D:\Working\fitness\docs\app\COVERAGE.md'
patch(C, [
("""compares that with what the goal wants, and uses the gap to choose exercises. It never touches a level,
a working set, or a verdict; it only decides which exercise fills a slot.""",
 """compares that with what the goal wants, and uses the gap to choose exercises. It also carries the two
dials for what is not lifting: how much of every workout goes to cardio and how much to stretching. It
never touches a level, a working set, or a verdict; it only decides which exercise fills a slot and how
the end of the workout is spent."""),
("""## Where it shows
""",
 """## Cardio and stretching

Two sliders beside the muscle ones, each a share of every workout's minutes.

| Slider | Default | Range | What it does |
|---|---|---|---|
| Cardio | 15 % | 0 to 50 % | reserved at the end of every workout, after the lifting; also takes any slack the lifting leaves |
| Stretching | 10 % | 0 to 30 % | reserved last, after cardio; one of the fixed mobility routines sized to the minutes |

A 60-minute workout at the defaults is 5 minutes of warm-up, 36 of lifting, 9 of cardio and 6 of
stretching. Cardio is a single duration with the effort tap at the end, as in a movement workout.
Stretching has no tap. At zero a block disappears, and with both at zero any slack is rest and the
workout says "no rush." Neither credits a muscle group for now. Movement workouts, a whole session of
cardio or mobility, stay as they are: the alternative to lifting, one tap away.

## Where it shows
"""),
("""- **Today:** when coverage changed a pick, one line under the exercise: "rows today, back is behind."
- **Settings → Goal:** the emphasis sliders.""",
 """- **Today:** when coverage changed a pick, one line under the exercise: "rows today, back is behind." Under
  the plan, the closing blocks: "then 9 min cardio, 6 min stretching."
- **Settings → Goal:** the emphasis sliders, and the cardio and stretching sliders beside them."""),
("""| Emphasis, per muscle group | none | 50 % less to 50 % more |""",
 """| Emphasis, per muscle group | none | 50 % less to 50 % more |
| Cardio, share of every workout | 15 % | 0 to 50 % |
| Stretching, share of every workout | 10 % | 0 to 30 % |"""),
("""- Whether cardio should credit the lower body a little, so a runner's plan tilts toward upper work.""",
 """- Whether cardio should credit the lower body a little, so a runner's plan tilts toward upper work.
- Whether stretching should follow coverage too: the routine picked by which groups were worked today."""),
])

W = r'D:\Working\fitness\docs\app\WORKOUT.md'
patch(W, [
("""mix; cardio fills whatever is left. There is no main lift and no accessory.""",
 """mix; cardio and stretching take the shares the user set, and cardio takes whatever is left. There is no
main lift and no accessory."""),
("""1. **The window** is the minutes picked, minus a five-minute warm-up, minus the cardio reservation.""",
 """1. **The window** is the minutes picked, minus a five-minute warm-up, minus the cardio and stretching
   shares from the sliders in `COVERAGE.md`."""),
("""5. **Cardio fills the rest.** The cardio setting is none, a reserved number of minutes, or filler. With
   none, the remainder is rest and the workout says "no rush."
""",
 """5. **Cardio and stretching close it.** Stretching takes its share last; cardio takes its share before
   that, plus any slack the lifting left. With both sliders at zero the slack is rest and the workout
   says "no rush."
"""),
("""| Cardio | filler | Settings → Goal: none, reserved minutes, or filler |""",
 """| Cardio and stretching, share of every workout | 15 % / 10 % | Settings → Goal, beside the emphasis sliders |"""),
])

A = r'D:\Working\fitness\docs\app\APPLICATION.md'
patch(A, [
("""- **Coverage.** Which muscle groups recent sets have worked, against what the goal wants. Chooses
  between candidate exercises; never touches a level. See `COVERAGE.md`.""",
 """- **Coverage.** Which muscle groups recent sets have worked, against what the goal wants. Chooses
  between candidate exercises; never touches a level. Also carries the cardio and stretching shares of
  every workout. See `COVERAGE.md`."""),
("""5. **Cardio fills the rest,** or rest does, by the cardio setting. More minutes always mean at least as
   many sets.""",
 """5. **Cardio and stretching close it,** each taking the share the user set, and cardio taking any slack.
   More minutes always mean at least as many sets."""),
("""| Cardio | filler | none, reserved minutes, filler |""",
 """| Cardio and stretching, share of every workout | 15 % / 10 % | 0 to 50 %, 0 to 30 % |"""),
("""- `COVERAGE.md`: which muscle groups recent sets have worked, the goal's emphasis, and how the gap chooses
  between exercises.""",
 """- `COVERAGE.md`: which muscle groups recent sets have worked, the goal's emphasis, how the gap chooses
  between exercises, and the cardio and stretching shares."""),
])
print('ok')
