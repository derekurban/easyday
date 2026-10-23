# APPLICATION.md: onboarding as five pages, and what the user sees after the UI rework (docs/app/UI.md).
def rw(p, fn):
    b=open(p,'rb').read(); s=b.decode('utf-8'); crlf='\r\n' in s
    s2=fn(s.replace('\r\n','\n'))
    if crlf: s2=s2.replace('\n','\r\n')
    open(p,'wb').write(s2.encode('utf-8'))

def f(s):
    old="""Onboarding asks for as little as possible and infers the rest from the first few workouts.

- **Goal.** The user's own, named and shaped in plain words. Templates are suggestions that fill every
  knob at a tap: the reps it likes, how many exercises and sets, the sets each muscle should get over
  which muscles are active, how often a movement day comes round. Any knob can be changed right there, or later in settings. The same goes for
  locations: name it, tick what is there, or fill it from a template first.
"""
    new="""Onboarding asks for as little as possible and infers the rest from the first few workouts: five pages, one
question each (how it works, the goal, about you, where you train, units), every answer a template or a tap,
everything changeable later in Settings (`UI.md`).

- **Goal.** The user's own, named and shaped in plain words. Templates are suggestions that fill every
  knob at a tap: the reps it likes, how many exercises and sets, the sets each muscle should get over
  which muscles are active, how often a movement day comes round. Onboarding picks the template; every knob
  can be changed later in Settings. The same goes for locations: a template on first run, then name it and
  tick what is there in Settings.
"""
    assert old in s; s=s.replace(old,new)
    old="""- **Today.** The day's name from the muscles it works, one line of numbers, the muscles panel (tap for the
  muscle picker), then the workout in order, warm-up to stretching, each exercise with its level, sets and
  minutes, and a bar of the whole. A row shows a tag only when today differs from the usual: next level,
  85 %, a version down, forced; never an exercise's class. Tap a row to swap, change the level, move or leave
  it out. The controls sit at the bottom where the thumb is: energy, time (minutes, or with the time limit
  off, how many exercises), move instead, muscles, reshuffle, and Start. Changing any of them rebuilds the
  workout in place.
"""
    new="""- **Today.** The day's name from the muscles it works as the title, one line of numbers with today against
  the usual at its right, the body figure painted with today's muscles (tap it for the muscle picker), then
  the plan: a row per part, warm-up to stretching, the exercise's level and sets on the left and its minutes
  on the right, a chevron on every row, and under it the strip as the workout will show it. A row shows a tag
  only when today differs from the usual: next level, 85 %, a version down, forced; never an exercise's
  class. Tap a row to swap, change today's level on the progression, move or leave it out. Shuffle sits by the
  plan; walk or stretch instead is a text link. The controls sit at the bottom where the thumb is: energy,
  time (the readout switches between minutes and, with the time limit off, how many exercises), and Start
  workout. Changing any of them rebuilds the workout in place. Every screen follows the same shape
  (`UI.md`): a title, a fact row, a picture, then sections; information loud, instruction quiet.
"""
    assert old in s; s=s.replace(old,new)
    old="""- **Words.** "Progression" and "level" are explained in plain words on first run, on every exercise card, and
  wherever a level can be edited: the progression is every step an exercise can get harder by, the level is the
  step you are on. No screen assumes the user knows the vocabulary.
"""
    new="""- **Words.** "Progression" and "level" are explained in plain words on first run and in How it works: the
  progression is every step an exercise can get harder by, the level is the step you are on. Wherever a level
  can be edited, the progression is drawn as a track with the level marked, so the words explain themselves
  there. No screen assumes the user knows the vocabulary, and no screen explains the engine beside its controls.
"""
    assert old in s; s=s.replace(old,new)
    old="""- **Exercise card.** Level, average time per set, best total at this level, cost with override, and the
  step guide.
- **Progress.** Workouts per month over time. Level trend per exercise, grouped by the chosen index. The
  strain muscle map of current strain points, a strip per muscle, and the strain points timeline. Each
  active muscle's rhythm, last worked and about every N workouts, and what helps each passive one. Days active this
  month. Nothing that resets to zero.
- **Settings.** The settings of section 9, in plain words, with the reminder, the calendar and the
  locations each in a section of their own.
"""
    new="""- **Exercise card.** The name, what it works and its difficulty, the stage picture, the level as facts
  (average time per set, best total at this level, workouts, the max), the how-to as numbered steps, the
  progression as a track, the reps it trains at, the difficulty with its override, and your word.
- **Exercises.** The library grouped by the chosen index, one line per exercise: the name, its level and set
  time when practised, the difficulty word at the right.
- **Progress.** Workouts per month over time, days active this month and workouts all time as facts. The
  strain muscle map of current strain points with one line, a strip per muscle, and the strain points
  timeline. Each active muscle's rhythm, about every N workouts and last worked, and what helps each passive
  one. Level trend per exercise, grouped by the chosen index. Recent workouts. Nothing that resets to zero.
- **Settings.** The settings of section 9, in plain words, one line per tile with the details behind the
  tap, with the reminder, the calendar and the locations each in a section of their own.
"""
    assert old in s; s=s.replace(old,new)
    old="""- `IDEAS.md`: things worth keeping that are not being built now.
"""
    new="""- `UI.md`: how every screen is laid out and worded: the rules found on the workout screen and the skeleton of
  each screen.
- `IDEAS.md`: things worth keeping that are not being built now.
"""
    assert old in s; s=s.replace(old,new)
    return s
rw('docs/app/APPLICATION.md', f)
print('ok')
