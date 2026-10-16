import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- model.dart: relative load on the exercise and the session
patch('lib/data/model.dart', [
("""  Expression expression; // the reps this set of sets is expressed in; the weight follows
  double? loadKg;     // loaded exercises: the weight today""",
 """  Expression expression; // the reps this set of sets is expressed in; the weight follows
  double? loadKg;     // loaded exercises: the weight today
  double relative = 1; // today's work against the user's usual (the working level): 0.6 lighter, 1 usual, 1.33 a set more"""),
("""        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'expression': _e(expression), 'loadKg': loadKg, 'secPerSet': secPerSet, 'sets': sets.map((s) => s.toJson()).toList(),""",
 """        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'expression': _e(expression), 'loadKg': loadKg, 'relative': relative, 'secPerSet': secPerSet, 'sets': sets.map((s) => s.toJson()).toList(),"""),
("""        warmups: ((j['warmups'] ?? []) as List).map((w) => Warmup.fromJson(w)).toList(), edited: j['edited'] ?? false, lightened: j['lightened'] ?? false,
      );
}""",
 """        warmups: ((j['warmups'] ?? []) as List).map((w) => Warmup.fromJson(w)).toList(), edited: j['edited'] ?? false, lightened: j['lightened'] ?? false,
      )..relative = (j['relative'] as num?)?.toDouble() ?? 1;
}"""),
("""  int spareMinutes;      // minutes left as rest when spare minutes are for rest
  bool circuit;""",
 """  int spareMinutes;      // minutes left as rest when spare minutes are for rest
  double relative = 1;   // the whole workout against the user's usual: below 1 lighter, 1 usual, above 1 more
  int pushes = 0;        // exercises given an extra set today
  bool noRoomToPush = false; // hard was picked but no extra set fit the minutes
  bool circuit;"""),
("""        'stretchMinutes': stretchMinutes, 'spareMinutes': spareMinutes,""",
 """        'stretchMinutes': stretchMinutes, 'spareMinutes': spareMinutes, 'relative': relative, 'pushes': pushes, 'noRoomToPush': noRoomToPush,"""),
])
t = io.open('lib/data/model.dart', encoding='utf-8').read()
old = "        spareMinutes: j['spareMinutes'] ?? 0,"
assert old in t
# find the end of Session.fromJson's constructor call to add the cascade
i = t.index(old)
j = t.index("    )", i)
k = t.index("\n", j)
tail = t[j:k]
assert tail.strip().startswith(')')
t = t[:j] + tail.replace(')', ")\n      ..relative = (j['relative'] as num?)?.toDouble() ?? 1\n      ..pushes = j['pushes'] ?? 0\n      ..noRoomToPush = j['noRoomToPush'] ?? false", 1) + t[k:]
io.open('lib/data/model.dart', 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- builder.dart: build the list once at normal, then turn the dials
patch('lib/logic/builder.dart', [
("""/// Intents by the energy recipe. Same exercises at every energy; only the dials move.
void _assignIntents(AppState s, List<_Slot> slots, Energy energy, GoalConfig g) {
  switch (energy) {
    case Energy.easy:
      for (final sl in slots) { sl.intent = intentLight; }
      // two working turns, among the easy and medium exercises only, the longest-waiting first. Hard ones stay light.
      final eligible = slots.where((x) => _difficulty(s, x.pick!) <= 2).toList()..sort((a, b) => _waitedLongest(s, a, b));
      for (final sl in eligible.take(2)) { sl.intent = intentWorking; }
    case Energy.normal:
      for (final sl in slots) { sl.intent = intentWorking; }
    case Energy.hard:
      for (final sl in slots) { sl.intent = intentWorking; }
      final byDifficulty = slots.toList()..sort((a, b) { final c = _difficulty(s, b.pick!).compareTo(_difficulty(s, a.pick!)); return c != 0 ? c : a.priority.compareTo(b.priority); });
      final n = g.extras <= 0 ? byDifficulty.length : g.extras;
      for (final sl in byDifficulty.take(n)) { sl.intent = intentExtra; }
  }
  for (final sl in slots) { sl.sets = setsFor(sl.intent, g.workingSets); }
}""",
 """/// The dials for one energy, on a list that is already built and fitted at normal. The list never changes here.
/// Returns how many extra sets were placed (hard) so the workout can say when none fit.
int _turnDials(AppState s, List<_Slot> slots, Energy energy, GoalConfig g, double window) {
  switch (energy) {
    case Energy.easy:
      for (final sl in slots) { sl.intent = intentLight; sl.sets = setsFor(intentLight, g.workingSets); }
      // two working turns, among the easy and medium exercises only, the longest-waiting first. Hard ones stay light.
      final eligible = slots.where((x) => _difficulty(s, x.pick!) <= 2).toList()..sort((a, b) => _waitedLongest(s, a, b));
      for (final sl in eligible.take(2)) { sl.intent = intentWorking; sl.sets = setsFor(intentWorking, g.workingSets); }
      return 0;
    case Energy.normal:
      return 0;
    case Energy.hard:
      // one more set on the hardest, as many as the setting asks and the minutes allow. An extra that does not fit is skipped.
      final byDifficulty = slots.toList()..sort((a, b) { final c = _difficulty(s, b.pick!).compareTo(_difficulty(s, a.pick!)); return c != 0 ? c : a.priority.compareTo(b.priority); });
      final n = g.extras <= 0 ? byDifficulty.length : g.extras;
      var placed = 0;
      for (final sl in byDifficulty.take(n)) {
        final st = ensureState(s, sl.pick!);
        if (_totalSeconds(s, slots) + st.secPerSet <= window) { sl.intent = intentExtra; sl.sets = setsFor(intentExtra, g.workingSets); placed++; }
      }
      return placed;
  }
}"""),
("""  // 3. intents by the recipe; 4. fit the minutes; 5. spare minutes
  _assignIntents(s, slots, o.energy, g);
  final dropped = _fitTime(s, slots, window, g);
  if (g.spare == Spare.exercises) {
    final more = [...dropped, ...all.where((p) => !patternsToday.contains(p))];
    _grow(s, slots, window, o.energy, g, equipment, more, plan.paused);
  }
  final usedSeconds = _totalSeconds(s, slots);
  final slack = ((window - usedSeconds) / 60).floor();
  var spareMin = 0;
  if (slack > 0 && slots.isNotEmpty) {
    if (g.spare == Spare.rest) { spareMin = slack; } else { cardioMin += slack; }
  }""",
 """  // 3. the list is built once, at normal: working sets everywhere, fitted to the minutes, spare minutes spent.
  //    Energy then turns the dials on exactly that list, so easy, normal and hard show the same exercises.
  for (final sl in slots) { sl.intent = intentWorking; sl.sets = setsFor(intentWorking, g.workingSets); }
  final dropped = _fitTime(s, slots, window, g);
  if (g.spare == Spare.exercises) {
    final more = [...dropped, ...all.where((p) => !patternsToday.contains(p))];
    _grow(s, slots, window, Energy.normal, g, equipment, more, plan.paused);
  }
  // 4. the dials
  final pushes = _turnDials(s, slots, o.energy, g, window);
  final usedSeconds = _totalSeconds(s, slots);
  final slack = ((window - usedSeconds) / 60).floor();
  var spareMin = 0;
  if (slack > 0 && slots.isNotEmpty) {
    if (g.spare == Spare.rest) { spareMin = slack; } else { cardioMin += slack; }
  }"""),
("""    final load = ex.loaded ? loadFor(s, ex, st, rung, expr) : null;
    out.add(SessionExercise(""",
 """    final load = ex.loaded ? loadFor(s, ex, st, rung, expr) : null;
    // today's work against the usual: sets against the working sets, times the weight share (or one version down), times the reserve
    var relative = sl.sets / g.workingSets;
    if (light) relative *= (ex.loaded ? expressionPct[expr]! / expressionPct[expressionFor(s, ex)]! : 0.85) * 0.9;
    out.add(SessionExercise("""),
("""      edited: edited, lightened: lightened,
    ));
  }

  return Session(""",
 """      edited: edited, lightened: lightened,
    )..relative = relative);
  }
  final weight = out.fold(0, (a, e) => a + e.difficulty);
  final relative = weight == 0 ? 1.0 : out.fold(0.0, (a, e) => a + e.relative * e.difficulty) / weight;

  return Session("""),
("""    stretchMinutes: out.isEmpty ? 0 : stretchMin, spareMinutes: spareMin, circuit: o.circuit,
  );
}""",
 """    stretchMinutes: out.isEmpty ? 0 : stretchMin, spareMinutes: spareMin, circuit: o.circuit,
  )..relative = relative..pushes = pushes..noRoomToPush = o.energy == Energy.hard && pushes == 0 && out.isNotEmpty;
}

/// Words for a relative load: how today compares with the usual working level.
String relativeLabel(double r) => r < 0.95 ? 'lighter' : r > 1.05 ? 'more' : 'usual';"""),
])

# ---------------- widgets.dart: the usual meter
t = io.open('lib/ui/widgets.dart', encoding='utf-8').read()
t = t.rstrip('\n') + '''

/// Today's work against the usual, as three bars: one lighter, two usual, three more. Relative, never a class.
class UsualMeter extends StatelessWidget {
  const UsualMeter(this.relative, {super.key, this.size = 6});
  final double relative;
  final double size;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final filled = relative < 0.95 ? 1 : relative > 1.05 ? 3 : 2;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 3; i++)
        Container(width: size * 1.6, height: size * (0.6 + 0.4 * i), margin: EdgeInsets.only(right: size * 0.4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: i <= filled ? du.accentStrong : du.line)),
    ]);
  }
}
'''
io.open('lib/ui/widgets.dart', 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- today.dart: the rows and header show the relative load; difficulty stays in the sheet
patch('lib/ui/today.dart', [
("                if (session.type == 'lift') _pill(context, LucideIcons.repeat, '$setCount sets'),",
 "                if (session.type == 'lift') _pill(context, LucideIcons.repeat, '$setCount sets'),\n                if (session.type == 'lift') _pill(context, LucideIcons.gauge, _usualText(session)),"),
("                      if (session.type == 'lift') Tooltip(message: 'Difficulty of the workout', child: CostDots(_avgCost(session).round())),",
 "                      if (session.type == 'lift') Tooltip(message: 'Against your usual', child: UsualMeter(session.relative)),"),
("""  double _avgCost(Session session) => session.exercises.isEmpty ? 0 : session.exercises.fold(0, (a, e) => a + e.difficulty) / session.exercises.length;""",
 """  String _usualText(Session session) {
    final r = session.relative;
    if (session.noRoomToPush) return 'your usual; no room to push';
    if (r > 1.05) return 'your usual, plus ${session.pushes} extra set${session.pushes == 1 ? '' : 's'}';
    if (r < 0.95) return '${(r * 20).round() * 5} % of your usual';
    return 'your usual';
  }"""),
("""        CostDots(e.difficulty),
        const SizedBox(height: 6),
        Text(intentLabel[e.intent] ?? e.intent, style: t.labelSmall?.copyWith(color: du.inkTertiary)),""",
 """        UsualMeter(e.relative),
        const SizedBox(height: 6),
        Text(e.intent == intentExtra ? '+1 set' : e.intent == intentLight ? '${(e.relative * 20).round() * 5} %' : 'usual', style: t.labelSmall?.copyWith(color: du.inkTertiary)),"""),
("""        Energy.easy => weekAway ? 'A week away: easy is the default today. Lighter weight, more reps, a set fewer, nothing judged. Two exercises at full.' : 'Same exercises, lighter weight and more reps, a set fewer, nothing judged. Two exercises at full.',
        Energy.normal => 'Same exercises at your working level: your weight, your sets, aim for the top. The work is what counts.',
        Energy.hard => 'Same exercises, one more set on the hardest. Working sets plus one, all at the top, levels up today.',""",
 """        Energy.easy => weekAway ? 'A week away: easy is the default today. The same exercises at about 60 % of your usual: lighter weight, more reps, a set fewer. Two of the easier ones at full.' : 'The same exercises at about 60 % of your usual: lighter weight, more reps, a set fewer, nothing judged. Two of the easier ones at full.',
        Energy.normal => 'The same exercises at your usual: your weight, your sets, aim for the top. The work is what counts.',
        Energy.hard => 'The same exercises at your usual, plus one more set on the hardest. Working sets plus one, all at the top, levels up today.',"""),
])

# ---------------- tests
patch('test/logic_test.dart', [
("""    test('energy never changes the exercises: the same list at easy, normal and hard', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 90);
      List<String> ids(Session x) => x.exercises.where((e) => !e.slot.endsWith('x')).map((e) => e.exId).toList()..sort();
      final easy = build(s, energy: Energy.easy, minutes: 60), normal = build(s, minutes: 60), hard = build(s, energy: Energy.hard, minutes: 60);
      expect(ids(easy), ids(normal));
      expect(ids(hard), ids(normal));
    });""",
 """    test('energy never changes the exercises: the same list at easy, normal and hard, added ones included', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 90);
      List<String> ids(Session x) => x.exercises.map((e) => e.exId).toList()..sort();
      for (final m in [25, 35, 60, 90]) {
        final easy = build(s, energy: Energy.easy, minutes: m), normal = build(s, minutes: m), hard = build(s, energy: Energy.hard, minutes: m);
        expect(ids(easy), ids(normal), reason: '$m');
        expect(ids(hard), ids(normal), reason: '$m');
        expect(easy.relative, lessThan(normal.relative), reason: '$m');
        expect(normal.relative, closeTo(1, 0.01), reason: '$m');
        expect(hard.relative, greaterThanOrEqualTo(normal.relative), reason: '$m');
        expect(sets(easy), lessThan(sets(normal)), reason: '$m');
        expect(sets(hard), greaterThanOrEqualTo(sets(normal)), reason: '$m');
      }
    });

    test('hard says so when no extra set fits the minutes, instead of dropping an exercise', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 150);
      final hard = build(s, energy: Energy.hard, minutes: 25), normal = build(s, minutes: 25);
      expect(hard.exercises.length, normal.exercises.length);
      if (hard.pushes == 0) expect(hard.noRoomToPush, isTrue);
      final roomy = build(s, energy: Energy.hard, minutes: 90);
      expect(roomy.pushes, 1);
      expect(roomy.noRoomToPush, isFalse);
    });"""),
("""    test('a tight window turns extra sets back to working before it drops an exercise', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 120);
      final hard = build(s, energy: Energy.hard, minutes: 30);
      final normal = build(s, minutes: 30);
      expect(hard.exercises.length, normal.exercises.length);
    });

""", ""),
])
print('ok')
