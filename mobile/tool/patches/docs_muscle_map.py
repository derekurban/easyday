# Moves the cardio and stretching shares from COVERAGE.md into WORKOUT.md and points the notes at MUSCLE_MAP.md.
import pathlib, sys
root = pathlib.Path(sys.argv[1])

def edit(name, pairs):
    p = root / name
    text = p.read_bytes().decode('utf-8').replace('\r\n', '\n')
    for old, new in pairs:
        if old not in text:
            raise SystemExit(f'{name}: not found: {old[:60]!r}')
        text = text.replace(old, new, 1)
    p.write_bytes(text.replace('\n', '\r\n').encode('utf-8'))

cardio = '''## Cardio and stretching

Two sliders in Settings → Goal, each a share of every workout's minutes.

| Slider | Default | Range | What it does |
|---|---|---|---|
| Cardio | 15 % | 0 to 50 % | reserved at the end of every workout, after the lifting; also takes any slack the lifting leaves |
| Stretching | 10 % | 0 to 30 % | reserved last, after cardio; one of the fixed mobility routines sized to the minutes |

A 60-minute workout at the defaults is 45 minutes of lifting, 9 of cardio and 6 of stretching. Cardio is a single
duration with the effort tap at the end, as in a movement workout. Stretching has no tap. At zero a block
disappears, and with both at zero any slack is rest and the workout says "no rush." Neither gives strain points
for now. Movement workouts, a whole session of cardio or mobility, stay as they are: the alternative to lifting,
one tap away.

## A time limit, or a number of exercises
'''

edit('WORKOUT.md', [
    ('## A time limit, or a number of exercises\n', cardio),
    ('   more than one candidate, coverage chooses (`COVERAGE.md`). Energy plays no part.',
     '   more than one candidate, the muscle map chooses by strain points, and a pattern whose candidates all\n'
     '   carry strain on a primary muscle sits out for another (`MUSCLE_MAP.md`). Energy plays no part.'),
    ('(`LOCATION.md`). Coverage chooses between candidates (`COVERAGE.md`).',
     '(`LOCATION.md`). The muscle map chooses between candidates by strain points (`MUSCLE_MAP.md`).'),
    ('| Settings → Goal, beside the emphasis sliders |', '| Settings → Goal |'),
    ('- How many workouts of history coverage needs before easy\'s catch-up picks beat the goal\'s order. Two\n  is the guess.\n', ''),
])

edit('APPLICATION.md', [
    ('| Emphasis per muscle group | none | 50 % less to 50 % more |\n', ''),
])

edit('EXERCISES.md', [
    ('coverage chooses among them (`COVERAGE.md`)', 'the muscle map chooses among them by strain points (`MUSCLE_MAP.md`)'),
])

edit('IDEAS.md', [
    ('  muscles the first exercises use, the way stretching could follow coverage.',
     '  muscles the first exercises use, the way stretching could follow strain points.'),
    ('- **Stretching that follows coverage.** The mobility routine at the end picked by which muscle groups',
     '- **Stretching that follows strain points.** The mobility routine at the end picked by which muscle groups'),
    ('## Coverage\n',
     '''## Muscle map and plans

- **Splits and a cycle designer.** Plans made of days, each a focus (full body, upper, lower, push, pull, legs,
  or a custom set of muscle groups) or a movement day (cardio, mobility, either), in a cycle the user can
  design: three full-body days then mobility, or a week of five lifting days and two mobility days. Templates for
  quick starts, and strain points choosing which day is today when the next one's muscles still carry strain.
- **Emphasis per muscle group.** A slider per group, 50 % less to 50 % more, tilting which exercises the muscle
  map picks over time. Was part of coverage; never built.
- **A share target and a deficit.** Coverage's idea of an even share per group over the last rotation, with the
  furthest behind chosen first. Strain points answer "is this muscle ready"; a deficit would answer "has it
  had its share". Never built.
'''),
])

(root / 'COVERAGE.md').unlink()
