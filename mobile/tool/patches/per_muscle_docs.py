"""Docs: selection, its ledgers and the muscle plan run per muscle; groups stay for browsing. CRLF kept."""
import pathlib, sys

root = pathlib.Path(__file__).resolve().parents[3] / 'docs' / 'app'

def patch(name, pairs):
    p = root / name
    b = p.read_bytes()
    crlf = b'\r\n' in b
    s = b.decode('utf-8').replace('\r\n', '\n')
    for old, new in pairs:
        if old not in s:
            sys.exit(f'{name}: not found: {old[:70]!r}')
        s = s.replace(old, new, 1)
    if crlf:
        s = s.replace('\n', '\r\n')
    p.write_bytes(s.encode('utf-8'))

patch('SELECTION.md', [
    ("""- **Share.** Should this muscle work today. The sets a muscle group has had over the look-back, against the
  target the goal sets for it,""", """- **Share.** Should this muscle work today. The sets a muscle has had over the look-back, against the
  target the goal sets for it,"""),
    ("""- **Counting.** A working set gives one to the group of each primary muscle and a half to the group of each
  secondary one.""", """- **Counting.** A working set gives one to each primary muscle and a half to each secondary one."""),
    ("""- **The target.** Sets per muscle group over the look-back, one number for every group, seeded from days per""",
     """- **The target.** Sets per muscle over the look-back, one number for every muscle, seeded from days per"""),
    ("""- **Emphasis.** Less, usual or more, per group: half, one, and one and a half times the target. "More back"
  keeps the back behind for longer,""", """- **Emphasis.** Less, usual or more, per muscle: half, one, and one and a half times the target. "More lats"
  keeps the lats behind for longer,"""),
    ("""The groups are the eleven of the muscle index (`EXERCISES.md`): chest, back, shoulders, biceps, triceps,
forearms, core, glutes, quads, hamstrings, calves.""", """The muscles are the map's own nineteen (`MUSCLE_MAP.md`), every one but the shins: chest; front, side and
rear shoulders; biceps, triceps, forearms; abs, obliques; traps, lats, upper back, lower back; glutes, outer
hips, inner thighs, quads, hamstrings, calves. Selection, the share ledger, emphasis and the muscle picker all
run on these, so what the user taps on the body is what the ledgers count. The eleven groups of the muscle
index (`EXERCISES.md`) are for browsing the library only. Saved emphasis from before, which was per group,
spreads to each of the group's muscles.

Small muscles that compound lifts barely reach as a helper (outer hips, side shoulders) start furthest
behind, so with nothing else to separate them they come up early and often. Emphasis less on them, or a
target scaled by size, is the knob if that is too much (open questions)."""),
    ("""is named for every muscle group it works, in order, as a day: "Chest day", "Back and biceps day", "Back, triceps
and forearms day".""", """is named for every muscle its places went to, in order, as a day: "Chest day", "Lats and biceps day",
"Upper back, triceps and forearms day". Long names are known and left for later."""),
    ("""- **The muscle plan.** Before the workout is built, every muscle group is in one of three states for today.
  *Excluded*: not worked, not even to fill spare minutes.""", """- **The muscle plan.** Before the workout is built, every muscle is in one of three states for today.
  *Excluded*: never takes a place, not even to fill spare minutes, and no exercise works it as a primary
  muscle (a forced muscle whose every exercise works an excluded one too still gets one)."""),
    ("""The defaults come from the muscle map: a group whose most strained muscle is
  at any shade starts excluded""", """The defaults come from the muscle map: a muscle at any shade starts excluded"""),
    ("""A list view shows the groups under""", """A list view shows the muscles under"""),
    ("""forced groups in the primary green, the available groups""", """forced muscles in the primary green, the available muscles"""),
    ("""fills the places after the forced groups from the available pool by the rules
  above, and Draw again takes ready groups at random instead of by share; *Manual* works the forced groups
  only. Done rebuilds the workout. A forced group still carrying strain is worked anyway, and its why-line
  says so. When every group is excluded,""", """fills the places after the forced muscles from the available pool by the rules
  above, and Draw again takes ready muscles at random instead of by share; *Manual* works the forced muscles
  only. Done rebuilds the workout. A forced muscle still carrying strain is worked anyway, and its why-line
  says so. When every muscle is excluded,"""),
    ("""- **Progress:** the share strip: the eleven groups, sets over the look-back""", """- **Progress:** the share strip: the nineteen muscles, sets over the look-back"""),
    ("""- **Settings → Goal:** the look-back, the sets target, emphasis per group,""", """- **Settings → Goal:** the look-back, the sets target, emphasis per muscle,"""),
    ("""- Less is half, never none. A group with no sets""", """- Less is half, never none. A muscle with no sets"""),
    ("""| Sets per muscle group over the look-back |""", """| Sets per muscle over the look-back |"""),
    ("""| Emphasis, per muscle group |""", """| Emphasis, per muscle |"""),
    ("""- Whether a group's target should come from capacity instead of a setting (`IDEAS.md`).""",
     """- Whether a muscle's target should come from capacity instead of a setting (`IDEAS.md`), or be scaled by its
  size, so the small muscles stop coming up as often as the big ones.
- Whether the day's name should fold muscles back into groups ("Back day" for lats and upper back)."""),
])

patch('APPLICATION.md', [
    ("""how many sets each muscle group should get over the look-back and which groups get more or
  less,""", """how many sets each muscle should get over the look-back and which muscles get more or
  less,"""),
    ("""- **Share.** The sets a muscle group has had over the look-back,""", """- **Share.** The sets a muscle has had over the look-back,"""),
    ("""- **Emphasis.** Less, usual or more, per muscle group. Scales that group's share target.""",
     """- **Emphasis.** Less, usual or more, per muscle. Scales that muscle's share target."""),
    ("""   named for the muscle groups it works ("Back and biceps day"),""", """   named for the muscles it works ("Lats and biceps day"),"""),
    ("""every group excluded, available or forced, chosen on the body""", """every muscle excluded, available or forced, chosen on the body"""),
    ("""the sets each muscle group should get over
  the look-back,""", """the sets each muscle should get over
  the look-back,"""),
    ("""Seeds the sets target per muscle group; never fixes days.""", """Seeds the sets target per muscle; never fixes days."""),
    ("""**Goal translation** maps the chosen goal to the reps it likes, the sets each muscle group should get,""",
     """**Goal translation** maps the chosen goal to the reps it likes, the sets each muscle should get,"""),
    ("""level trend per muscle group, each group's share of the
  look-back,""", """level trend per muscle group, each muscle's share of the
  look-back,"""),
    ("""| Look-back for a muscle group's share |""", """| Look-back for a muscle's share |"""),
    ("""| Sets per muscle group over the look-back |""", """| Sets per muscle over the look-back |"""),
    ("""| Emphasis, per muscle group |""", """| Emphasis, per muscle |"""),
    ("""the list has the groups under those three headings""", """the list has the muscles under those three headings"""),
    ("""Each
  muscle group's share of the look-back against its target,""", """Each
  muscle's share of the look-back against its target,"""),
])

patch('MUSCLE_MAP.md', [
    ("""The eleven muscle groups of the index in
`EXERCISES.md` fold these names for browsing; the muscle map itself always works by muscle.""",
     """The eleven muscle groups of the index in
`EXERCISES.md` fold these names for browsing; the muscle map, selection and its ledgers always work by muscle."""),
])
print('ok')
