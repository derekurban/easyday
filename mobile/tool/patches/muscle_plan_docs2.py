"""Docs: the picker selects then assigns, shuffle or manual, the four fills. CRLF kept."""
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
    ("""  nothing starts forced. The muscle picker on Today changes them: a tap on a muscle on the body cycles its
  group excluded, available, forced; a list view shows the groups under the three headings, each tile
  draggable up, down and between them, with its strain and its share beside it. Done rebuilds the workout.
  A forced group still carrying strain is worked anyway, and its why-line says so. When every group is
  excluded, or nothing here works the available ones, Today says so and offers the picker or a movement day.
""", """  nothing starts forced. The muscle picker on Today changes them: tap muscles on the body to select them
  (blue), then one of three pills says what the selected ones are today. A list view shows the groups under
  the three headings, each tile draggable up, down and between them, with its strain and its share beside it.
  The figure shows the result like a muscle map: forced groups in the primary green, the available groups
  the workout chose in the secondary green, the other available ones plain, excluded ones very dark.
  *Shuffle* (the default) fills the places after the forced groups from the available pool by the rules
  above, and Draw again takes ready groups at random instead of by share; *Manual* works the forced groups
  only. Done rebuilds the workout. A forced group still carrying strain is worked anyway, and its why-line
  says so. When every group is excluded, or nothing here works the available ones, Today says so and offers
  the picker or a movement day.
"""),
    ("""- **Today:** the day's name, the muscles panel (a small figure painted like the picker: forced green, excluded
  red for strain or dim, available plain) saying what is worked, forced and excluded, and the picker behind it.
""", """- **Today:** the day's name, the muscles panel (a small figure painted like the picker: forced primary green,
  chosen secondary, excluded dark, available plain) saying what is worked, forced and excluded, and the picker
  behind it.
"""),
])

patch('APPLICATION.md', [
    ("""- **The muscle picker.** The body, front and back, with a stack of view tabs at the bottom right: both,
  front, back, list. A tap on a muscle cycles its group excluded, available, forced; the list has the groups
  under those three headings, draggable between them. A line above Done previews the day's name, count and
  minutes as the states change.
""", """- **The muscle picker.** The body, front and back, with a stack of view tabs at the bottom right: both,
  front, back, list. Tap muscles to select them, then a pill makes the selected ones forced, available or
  excluded; the list has the groups under those three headings, draggable between them. Shuffle or Manual at
  the top says whether the workout is drawn from the available pool (Draw again for another draw) or works
  the forced muscles only. A line above Done previews the day's name, count and minutes as the plan changes.
"""),
])
print('ok')
