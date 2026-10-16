import os
root = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'docs', 'app')

def patch(name, pairs):
    p = os.path.join(root, name)
    s = open(p, encoding='utf-8').read()
    for old, new in pairs:
        assert old in s, (name, old[:70])
        s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)

patch('APPLICATION.md', [
("""- **Today.** One workout, one start button, the energy picker and the minutes slider with their defaults
  filled, the swap control, and the location. Every row and the whole workout against the user's usual,
  so easy, normal and hard read as lighter, usual and more at a glance; never an exercise's class.""",
"""- **Today.** The workout first: its name, one line of numbers, a body map of what it targets against what
  was worked lately with two or three lines saying why, then the rows. The controls sit at the bottom
  where the thumb is: energy, minutes, reshuffle, move instead, circuit, and the start button. Changing
  any of them rebuilds the workout in place. A row shows a tag only when today differs from the usual:
  next level, 85 %, a version down; never an exercise's class."""),
])

patch('EXERCISES.md', [
("""- **In a workout:** name, level, the how-to for that level, target reps, cost dots. Swapping to another""",
"""- **In a workout:** name, level, the how-to for that level, target reps, the difficulty as a word. Swapping to another"""),
])

patch('WORKOUT.md', [
("""Every exercise is easy, medium or hard: how much one hard set takes out of the whole body. Three dots on
every row, a word on the card, an index in the catalog, and an override on the card.""",
"""Every exercise is easy, medium or hard: how much one hard set takes out of the whole body. The word in a
small pill in the catalog and during a workout, on the card with its override, and an index in the catalog.
Never dots: a newcomer should not have to decode them."""),
])

patch('COVERAGE.md', [
("""## Where it shows
""", """## Built so far

As of 0.13.0 the muscle side is shown, not yet used to choose: a body map (front and back, the eleven
groups) filled by how worked each group is, from the sets of the last five days faded by the days since,
one point per set on the first primary group and half on each secondary, light sets half of that. Today
outlines the groups the planned workout targets over that fill and says in words what is fresh and what
was worked when. Progress shows the same map with a fourteen-day strip and "last worked" per group. The
credits, window and deficit that would choose exercises are not built; the builder still takes the usual
pick for a pattern.

## Where it shows
"""),
])
print('docs ok')
