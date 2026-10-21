"""Tags and how often on the goal, template defaults in the library, docs cross-references. CRLF kept."""
import pathlib, sys

mobile = pathlib.Path(__file__).resolve().parents[2]
docs = mobile.parent / 'docs' / 'app'

def patch(p, pairs, force_crlf=None):
    b = p.read_bytes()
    crlf = (b'\r\n' in b) if force_crlf is None else force_crlf
    s = b.decode('utf-8').replace('\r\n', '\n')
    for old, new in pairs:
        if old not in s:
            sys.exit(f'{p.name}: not found: {old[:80]!r}')
        s = s.replace(old, new, 1)
    if crlf:
        s = s.replace('\n', '\r\n')
    p.write_bytes(s.encode('utf-8'))

patch(mobile / 'lib/data/model.dart', [
    ("""const emphasisShare = {-1: 0.5, 0: 1.0, 1: 1.5};
const lookBackMin = 3, lookBackMax = 14, lookBackDefault = 7;
const setsTargetMin = 2, setsTargetMax = 30;""", """/// How often an active muscle's turn comes round, against its plain turn: less is half as often, more twice.
const oftenLabel = {-1: 'Less', 0: 'Usual', 1: 'More'};
const oftenFactor = {-1: 0.5, 0: 1.0, 1: 2.0};

/// The user's word on a muscle (SELECTION.md): active gets exercises of its own and is measured by direct work;
/// passive gets none, steers exercise choice, and is measured by any work; ignored is not considered.
enum MuscleTag { active, passive, ignored }

const muscleTagLabel = {MuscleTag.active: 'Active', MuscleTag.passive: 'Passive', MuscleTag.ignored: 'Ignored'};
const muscleTagBlurb = {
  MuscleTag.active: 'Gets exercises of its own, in turn. Only a set where it is a main muscle counts.',
  MuscleTag.passive: 'No exercise of its own. Helper work counts, and it steers which exercise is chosen.',
  MuscleTag.ignored: 'Not considered. It may still help in an exercise; nobody counts.',
};"""),
    ("""    this.lookBackDays = lookBackDefault, this.setsTarget, Map<String, int>? emphasis, this.explore = Explore.rarely,
  }) : bands = [for (final b in bands) b.copy()], emphasis = {...?emphasis};""",
     """    Map<String, int>? often, Map<String, MuscleTag>? tags, this.explore = Explore.rarely,
  }) : bands = [for (final b in bands) b.copy()], often = {...?often}, tags = {...?tags};"""),
    ("""  int lookBackDays;      // the days a muscle group's share looks back over (3 to 14)
  int? setsTarget;       // sets per muscle group over the look-back; null is seeded from days per week
  Map<String, int> emphasis;  // muscle group -> -1 less, 1 more; absent is usual
  Explore explore;       // how often an unrated exercise takes a turn

  /// The working set count: the usual.
  int get workingSets => sets.ideal;

  /// The sets target per muscle group over the look-back, the setting or the seed from days per week.
  int targetSets(int daysPerWeek) => setsTarget ?? seedSetsTarget(daysPerWeek);

  /// A group's emphasis: -1 less, 0 usual, 1 more.
  int emphasisOf(String muscle) => emphasis[muscle] ?? 0;

  /// A group's target: the sets target scaled by its emphasis, half, one or one and a half.
  double targetFor(String muscle, int daysPerWeek) => targetSets(daysPerWeek) * emphasisShare[emphasisOf(muscle)]!;

  void setEmphasis(String muscle, int v) {
    if (v == 0) { emphasis.remove(muscle); } else { emphasis[muscle] = v.clamp(-1, 1); }
  }
""", """  Map<String, int> often;         // muscle -> -1 less, 1 more often; absent is usual
  Map<String, MuscleTag> tags;    // muscle -> its tag where it differs from the template's default
  Explore explore;       // how often an unrated exercise takes a turn

  /// The working set count: the usual.
  int get workingSets => sets.ideal;

  /// How often a muscle's turn comes round: -1 less, 0 usual, 1 more.
  int oftenOf(String muscle) => often[muscle] ?? 0;

  void setOften(String muscle, int v) {
    if (v == 0) { often.remove(muscle); } else { often[muscle] = v.clamp(-1, 1); }
  }

  /// A muscle's tag: the user's, else the template's default (the shins ignored everywhere).
  MuscleTag tagOf(String muscle) => tags[muscle] ?? defaultTag(template, muscle);

  void setTag(String muscle, MuscleTag tag) {
    if (tag == defaultTag(template, muscle)) { tags.remove(muscle); } else { tags[muscle] = tag; }
  }

  /// The muscles that get exercises of their own, in the map's order.
  List<String> get activeMuscles => [for (final m in trackedMuscles) if (tagOf(m) == MuscleTag.active) m];
  List<String> get passiveMuscles => [for (final m in trackedMuscles) if (tagOf(m) == MuscleTag.passive) m];
"""),
    ("""    lookBackDays = lookBackDefault;
    setsTarget = null;
    emphasis = {};
    explore = Explore.rarely;""", """    often = {};
    tags = {};
    explore = Explore.rarely;"""),
    ("""        'lookBackDays': lookBackDays, 'setsTarget': setsTarget, 'emphasis': emphasis, 'explore': _e(explore),""",
     """        'often': often, 'tags': tags.map((k, v) => MapEntry(k, _e(v))), 'explore': _e(explore),"""),
    ("""      lookBackDays: ((j['lookBackDays'] ?? lookBackDefault) as int).clamp(lookBackMin, lookBackMax),
      setsTarget: j['setsTarget'] == null ? null : (j['setsTarget'] as int).clamp(setsTargetMin, setsTargetMax),
      emphasis: _emphasisFrom(j['emphasis'] as Map? ?? {}),""",
     """      // emphasis was the old name for how often, and per group before selection ran on muscles
      often: _oftenFrom((j['often'] ?? j['emphasis']) as Map? ?? {}),
      tags: {
        for (final e in (j['tags'] as Map? ?? {}).entries)
          if (trackedMuscles.contains(e.key)) e.key as String: _p(MuscleTag.values, e.value, MuscleTag.active),
      },"""),
    ("""/// Emphasis as saved: per muscle, or per group before selection ran on muscles, when a group's word spreads to each
/// of its muscles. A muscle's own word wins over its group's.
Map<String, int> _emphasisFrom(Map j) {""", """/// How often as saved: per muscle, or per group before selection ran on muscles, when a group's word spreads to each
/// of its muscles. A muscle's own word wins over its group's.
Map<String, int> _oftenFrom(Map j) {"""),
])

patch(mobile / 'lib/data/library.dart', [
    ("""  const Goal(this.id, this.name, this.blurb, {required this.program, required this.moveEvery, required this.exercises, required this.sets, required this.pushes, required this.explain});
  final String id;""", """  const Goal(this.id, this.name, this.blurb, {required this.program, required this.moveEvery, required this.exercises, required this.sets, required this.pushes, required this.explain, required this.active});
  final String id;
  final Set<String> active;  // the muscles the template marks active; the rest are passive, the shins ignored"""),
    ("""      program: 'strength', moveEvery: 4, exercises: Tri(2, 4, 6), sets: Tri(2, 3, 4), pushes: Tri(1, 2, 3),
      explain: ['Heavy and few: 4 to 7 reps on the hard exercises', 'One movement day in four', 'About 45 minutes a workout']),""",
     """      program: 'strength', moveEvery: 4, exercises: Tri(2, 4, 6), sets: Tri(2, 3, 4), pushes: Tri(1, 2, 3),
      explain: ['Heavy and few: 4 to 7 reps on the hard exercises', 'One movement day in four', 'About 45 minutes a workout'],
      active: bigMovers),"""),
    ("""      program: 'build', moveEvery: 4, exercises: Tri(2, 4, 6), sets: Tri(2, 3, 4), pushes: Tri(1, 2, 3),
      explain: ['Middle reps: 8 to 12', 'One movement day in four', 'About 40 minutes a workout']),""",
     """      program: 'build', moveEvery: 4, exercises: Tri(2, 4, 6), sets: Tri(2, 3, 4), pushes: Tri(1, 2, 3),
      explain: ['Middle reps: 8 to 12', 'One movement day in four', 'About 40 minutes a workout'],
      active: {...bigMovers, 'side shoulders', 'rear shoulders', 'biceps', 'triceps', 'calves'}),"""),
    ("""      program: 'endurance', moveEvery: 2, exercises: Tri(2, 4, 5), sets: Tri(2, 3, 3), pushes: Tri(1, 1, 2),
      explain: ['Light and many: 13 to 18 reps', 'Every other day is a movement day', 'About 35 minutes a workout']),""",
     """      program: 'endurance', moveEvery: 2, exercises: Tri(2, 4, 5), sets: Tri(2, 3, 3), pushes: Tri(1, 1, 2),
      explain: ['Light and many: 13 to 18 reps', 'Every other day is a movement day', 'About 35 minutes a workout'],
      active: {...bigMovers, 'calves'}),"""),
    ("""      program: 'endurance', moveEvery: 2, exercises: Tri(1, 3, 4), sets: Tri(2, 2, 3), pushes: Tri(0, 1, 2),
      explain: ['Three exercises, light and many', 'Every other day is a movement day', 'About 25 minutes a workout']),
};""", """      program: 'endurance', moveEvery: 2, exercises: Tri(1, 3, 4), sets: Tri(2, 2, 3), pushes: Tri(0, 1, 2),
      explain: ['Three exercises, light and many', 'Every other day is a movement day', 'About 25 minutes a workout'],
      active: bigMovers),
};

/// The muscles every template marks active: the big movers.
const bigMovers = {'quads', 'hamstrings', 'glutes', 'chest', 'lats', 'upper back', 'front shoulders', 'abs'};

/// A muscle's tag by template (SELECTION.md): the template's active set, the shins ignored, the rest passive. A custom
/// goal, or one from before tags, takes the build muscle template's.
MuscleTag defaultTag(String template, String muscle) {
  if (muscle == 'shins') return MuscleTag.ignored;
  final g = goals[template] ?? goals['muscle']!;
  return g.active.contains(muscle) ? MuscleTag.active : MuscleTag.passive;
}"""),
])

patch(mobile / 'lib/logic/after.dart', [
    ("""  for (final m in moreSuggestions(s, now)) {
    p.moreSuggested.add(m);
    lines.add('You keep asking for $m. Set it to more in Settings → Goal if you like.');""",
     """  for (final m in moreSuggestions(s, now)) {
    p.moreSuggested.add(m);
    lines.add(s.goal!.tagOf(m) == MuscleTag.active
        ? 'You keep forcing $m. Set it to more often in Settings → Goal if you like.'
        : 'You keep forcing $m. Mark it active in Settings → Goal if you like.');"""),
])

patch(mobile / 'lib/ui/onboarding.dart', [
    ("""      (title: 'How many days a week, roughly?', blurb: 'Seeds how many sets each muscle group aims for over a week. There are no fixed days: whenever you come back, a workout built from where your body is now is waiting.', body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ChoiceRow<int>(value: days, options: const {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 6: '6'}, onChanged: (v) => setState(() => days = v)),
        const SizedBox(height: 8),
        Text('About ${seedSetsTarget(days)} sets per muscle group every ${goal.lookBackDays} days. Change it any time in Settings → Goal.', style: t.bodySmall),
      ])),""", """      (title: 'How many days a week, roughly?', blurb: 'There are no fixed days: whenever you come back, a workout built from where your body is now is waiting. This only sets the pace the forecast assumes.', body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ChoiceRow<int>(value: days, options: const {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 6: '6'}, onChanged: (v) => setState(() => days = v)),
        const SizedBox(height: 8),
        Text('Your goal marks ${goal.activeMuscles.length} muscles active, each worked in turn. Change which, and how often, any time in Settings → Goal.', style: t.bodySmall),
      ])),"""),
])

# the docs: SELECTION.md was rewritten whole; make its endings match the rest, and point the others at the new words
sel = docs / 'SELECTION.md'
sel.write_bytes(sel.read_bytes().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))

patch(docs / 'APPLICATION.md', [
    ("""  difficulty, how many sets each muscle should get over the look-back and which muscles get more or
  less,""", """  difficulty, which muscles are active, passive or ignored and how often each active one comes round,"""),
    ("""- **Share.** The sets a muscle has had over the look-back, against the target the goal sets for it,
  scaled by its emphasis. Behind, on track, or done. The second question selection asks. See `SELECTION.md`.
- **Emphasis.** Less, usual or more, per muscle. Scales that muscle's share target.""",
     """- **Tag.** The user's word on a muscle: active (gets exercises of its own, measured by direct work),
  passive (incidental work is fine; steers exercise choice), or ignored. Set by the goal template, changed by
  the user. See `SELECTION.md`.
- **Turn.** Whose turn it is among the active muscles: the most strength workouts since it was last a main
  muscle, doubled for more often and halved for less. The second question selection asks.
- **How often.** Less, usual or more, per active muscle."""),
    ("""  the look-back, how often a movement day comes round.""", """  which muscles are active, how often a movement day comes round."""),
    ("""   behind their share over the look-back, emphasis first. As many as the goal's ideal count of exercises.""",
     """   whose turn it is, most overdue first. As many as the goal's ideal count of exercises can cover."""),
    ("""6. **Order it** emphasised muscles first, then hardest first;""", """6. **Order it** muscles marked more often first, then hardest first;"""),
    ("""- **Between workouts**: workouts per month, level trend per muscle group, each muscle's share of the
  look-back, days active this month. Never streaks.""", """- **Between workouts**: workouts per month, level trend per muscle group, each active muscle's rhythm (last
  worked, about every N workouts), days active this month. Never streaks."""),
    ("""| Look-back for a muscle's share | 7 days | 3 to 14 |
| Sets per muscle over the look-back | from days per week: 6, 8 or 10 | 2 to 30 |
| Emphasis, per muscle | usual | less, usual, more |""", """| Tag, per muscle | by the goal template | active, passive, ignored |
| How often, per active muscle | usual | less, usual, more |"""),
    ("""  muscle's share of the look-back against its target, with its emphasis beside it. Days active this""",
     """  active muscle's rhythm, last worked and about every N workouts, and what helps each passive one. Days active this"""),
    ("""- `SELECTION.md`: which muscles a workout works and which exercise works each one: readiness, share and
  emphasis, preference, trying something new, and the user's own picks.""", """- `SELECTION.md`: which muscles a workout works and which exercise works each one: tags, readiness, whose
  turn it is, the engine, preference, shuffling, the forecast, and the user's own picks."""),
])

patch(docs / 'WORKOUT.md', [
    ("""   their share, emphasis first, and for each the exercise the location allows that is ready, preferred and""",
     """   whose turn it is, most overdue first, and for each the exercise the location allows that is ready, preferred and"""),
    ("""7. **Order** emphasised muscles first, then hardest first, while the user is fresh; at the same difficulty,""",
     """7. **Order** muscles marked more often first, then hardest first, while the user is fresh; at the same difficulty,"""),
])

patch(docs / 'MUSCLE_MAP.md', [
    ("""  behind its share it is. Only the user's own pick of a muscle overrides this, and the plan says so.""",
     """  overdue its turn is. Only the user's own pick of a muscle overrides this, and the plan says so."""),
])
print('ok')
