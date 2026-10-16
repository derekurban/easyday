import io, re
p = '../APPLICATION.md'
s = io.open(p, encoding='utf-8').read()

# Vocabulary: ladder -> progression, rung -> level, session -> workout. Case-aware, plural-aware.
def sub(word, repl):
    global s
    for a, b in [(word, repl), (word.capitalize(), repl.capitalize()), (word + 's', repl + 's'), (word.capitalize() + 's', repl.capitalize() + 's')]:
        s = re.sub(r'\b' + a + r'\b', b, s)

sub('ladder', 'progression')
sub('rung', 'level')
sub('session', 'workout')
s = s.replace('Movement workout', 'Movement workout')  # keep
s = s.replace('one visit', 'one workout')

# New vocabulary and rules.
s = s.replace("""- **Progression and level.** Every exercise is a progression.""", """- **Progression and level.** Every exercise is a progression.""")
s = s.replace("""- **Set outcome.** Hit the top, a rep count below it, or not attempted. See section 8.""",
"""- **Set outcome.** Hit the top, a rep count below it, or not attempted. See section 8.
- **Mode.** Straight sets (all sets of one exercise, then the next) or circuit (one set of each exercise per
  round). Chosen before starting; it changes the order, nothing else.
- **Custom exercise.** One the user made: by weight (a start and a step) or by version (their own levels,
  each with its own how-to). It stands in for one slot type so workouts can use it.""")

s = s.replace("""- **Stop reason.** Why a workout or exercise ended early: out of energy, out of time, or something hurts.""",
"""- **Stop reason.** Why a workout ended early: out of energy, out of time, something hurts, or no reason.
  No reason is allowed and carries no penalty: nothing is judged and no default moves.""")

s = s.replace("""4. **Optional adjustments, one tap each.**""", """4. **Optional adjustments, one tap each.** Straight sets or circuit.""")

s = s.replace("""6. **Finish.** An optional one-tap rating: easy, right, or too much. Skipping is fine.""",
"""6. **Finish.** An optional one-tap rating: easy, right, or too much. Skipping is fine. Any exercise can be
   skipped mid-workout without being judged, and the workout can be ended with no reason given.""")

s = s.replace("""There is no step where the user plans, chooses exercises, or decides on weights. There is no "Tuesday
workout" to miss. Whenever they come back, the next workout is waiting.""",
"""There is no step where the user plans, chooses exercises, or decides on weights. There is no "Tuesday
workout" to miss. Whenever they come back, the next workout is waiting.

**Closure.** A finished workout closes the day. Today shows what changed and that the next workout is
ready tomorrow; nothing else is waiting. The next workout appears on the next calendar day, or at once if
the user asks for it. One workout a day is the shape people recognise; back-to-back is the exception.""")

s = s.replace("""- **Out of energy.** Nudges the energy default toward easy. Never a progression signal.""",
"""- **No reason.** Nothing. The sets done are kept; no level and no default moves.
- **Out of energy.** Nudges the energy default toward easy. Never a progression signal.""")

s = s.replace("""**Levels by equipment.**""", """**How-to follows the level.** Each level of a bodyweight progression carries its own description, so when
the level changes, the instructions change with it. Loaded exercises keep one description; only the weight
moves.

**Levels by equipment.**""")

s = s.replace("""## 12. Scheduling and automations""", """## 12. Scheduling, automations and integrations

Three integrations exist, each off until the user turns it on and grants the permission, each used for
one thing:

- **Notifications.** One reminder a day at a chosen hour, with the same calm line every time. Never more.
- **Calendar.** Reads only how busy today is. Six or more hours of events make the default twenty-five
  minutes.
- **Location.** Picks the nearest saved location when the app opens, if the user saved a position for it.""")

s = s.replace("""- **Catalog.** Rung, average time per set""", """- **Catalog.** Level, average time per set""")
s = s.replace("""- **Words.** "Progression" and "level" are explained in plain words on first run, on every exercise card, and
  wherever a level can be edited: the progression is every step an exercise can get harder by, the level is the
  step you are on. No screen assumes the user knows the vocabulary.""",
"""- **Words.** "Progression" and "level" are explained in plain words on first run, on every exercise card, and
  wherever a level can be edited: the progression is every step an exercise can get harder by, the level is the
  step you are on. No screen assumes the user knows the vocabulary. Movement patterns (squat, hinge, push,
  pull) stay inside the builder; the user only ever sees exercise names and levels.""")

io.open(p, 'w', encoding='utf-8').write(s)
print('spec ok; ladder left:', len(re.findall(r'\bladder', s, re.I)), 'rung left:', len(re.findall(r'\brung', s, re.I)), 'session left:', len(re.findall(r'\bsession', s, re.I)))
