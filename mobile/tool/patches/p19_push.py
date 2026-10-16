import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- model.dart: the push set
patch('lib/data/model.dart', [
("const defaultExtras = 1;", "const defaultExtras = 2;"),
("  int extras;            // exercises given an extra set on a hard day, 1 to 5; 0 means all",
 "  int extras;            // exercises given a level-up set on a hard day, 1 to 5; 0 means all"),
("""  double relative = 1; // today's work against the user's usual (the working level): 0.6 lighter, 1 usual, 1.33 a set more""",
 """  double relative = 1; // today's work against the user's usual (the working level): 0.6 lighter, 1 usual, 1.33 a set more
  int? pushRung;       // the push set: the last set, at the next level. Reach pushTarget and the level is yours today.
  String? pushLabel;
  int? pushTarget;

  bool isPush(int i) => pushRung != null && i == sets.length - 1;
  int targetAt(int i) => isPush(i) ? pushTarget! : target;"""),
("""        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'expression': _e(expression), 'loadKg': loadKg, 'relative': relative, 'secPerSet': secPerSet, 'sets': sets.map((s) => s.toJson()).toList(),""",
 """        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'expression': _e(expression), 'loadKg': loadKg, 'relative': relative,
        'pushRung': pushRung, 'pushLabel': pushLabel, 'pushTarget': pushTarget, 'secPerSet': secPerSet, 'sets': sets.map((s) => s.toJson()).toList(),"""),
("""      )..relative = (j['relative'] as num?)?.toDouble() ?? 1;
}""",
 """      )..relative = (j['relative'] as num?)?.toDouble() ?? 1
        ..pushRung = j['pushRung']
        ..pushLabel = j['pushLabel']
        ..pushTarget = j['pushTarget'];
}"""),
])

# ---------------- builder.dart: the push set at the next level
patch('lib/logic/builder.dart', [
("""    var relative = sl.sets / g.workingSets;
    if (light) relative *= (ex.loaded ? expressionPct[expr]! / expressionPct[expressionFor(s, ex)]! : 0.85) * 0.9;
    out.add(SessionExercise(""",
 """    var relative = sl.sets / g.workingSets;
    if (light) relative *= (ex.loaded ? expressionPct[expr]! / expressionPct[expressionFor(s, ex)]! : 0.85) * 0.9;
    // the push set: the next level, aim for the floor of the range; at the ceiling, the same level for two past the top
    int? pushRung;
    String? pushLabel;
    int? pushTarget;
    if (sl.intent == intentExtra) {
      final c = ceilingFor(ex, equipment);
      pushRung = c != null && rung >= c ? rung : rung + 1;
      pushLabel = rungLabel(s, ex, st, pushRung, expr);
      pushTarget = pushRung == rung ? range.hi + 2 : range.lo;
      relative *= 1.15;
    }
    out.add(SessionExercise("""),
("""    )..relative = relative);
  }""",
 """    )..relative = relative..pushRung = pushRung..pushLabel = pushLabel..pushTarget = pushTarget);
  }"""),
])

# ---------------- after.dart: the push set judged at its own target
patch('lib/logic/after.dart', [
("""  if (working.every((x) => x.reps! >= e.hi)) {
    final extra = e.sets.skip(e.workingSets).where((x) => x.attempted).toList();
    return extra.isNotEmpty && extra.first.reps! >= e.hi ? Verdict.stepNow : Verdict.hit;
  }""",
 """  if (working.every((x) => x.reps! >= e.hi)) {
    final extra = e.sets.skip(e.workingSets).where((x) => x.attempted).toList();
    final bar = e.pushTarget ?? e.hi;
    return extra.isNotEmpty && extra.first.reps! >= bar ? Verdict.stepNow : Verdict.hit;
  }"""),
("""          ups.add(v == Verdict.stepNow
              ? '${ex.name} levels up now: working sets plus one, all at the top.'
              : '${ex.name} levels up next time: you hit ${e.hi} on every set.');""",
 """          ups.add(v == Verdict.stepNow
              ? '${ex.name} levels up now: ${e.pushLabel != null ? 'you reached ${e.pushTarget} at ${e.pushLabel}' : 'working sets plus one, all at the top'}.'
              : '${ex.name} levels up next time: you hit ${e.hi} on every set.');"""),
])

# ---------------- session.dart: the push set has its own level and target
patch('lib/ui/session.dart', [
("""                  e.atCeiling
                      ? 'Top of the progression here. Beat ${e.bestTotal} total across ${e.sets.length} sets.'
                      : 'Aim for ${e.target}$unit every set. Range ${e.lo} to ${e.hi}. Hit the top on every set and the next level is yours.',""",
 """                  e.atCeiling
                      ? 'Top of the progression here. Beat ${e.bestTotal} total across ${e.sets.length} sets.'
                      : e.pushRung != null
                          ? 'Aim for ${e.target}$unit on ${e.workingSets} sets. Then a level-up set at ${e.pushLabel}: reach ${e.pushTarget}$unit and the level is yours today.'
                          : 'Aim for ${e.target}$unit every set. Range ${e.lo} to ${e.hi}. Hit the top on every set and the next level is yours.',"""),
("""                    decoration: BoxDecoration(
                      color: e.sets[i].attempted ? (e.sets[i].reps! >= e.hi ? du.accentSubtle : du.sunk) : du.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: i == nextSet && !skipped ? du.accentStrong : (e.sets[i].attempted ? du.accentLine : du.line), width: i == nextSet && !skipped ? 2 : 0.6),
                    ),
                    child: e.sets[i].attempted
                        ? (justLogged == i
                            ? Pop(key: ValueKey('p$i'), child: Text('${e.sets[i].reps}', style: t.headlineMedium?.copyWith(color: du.accentText)))
                            : Text('${e.sets[i].reps}', style: t.headlineMedium?.copyWith(color: du.accentText)))
                        : Text(i == nextSet && !skipped ? 'now' : '·', style: i == nextSet && !skipped ? t.labelMedium?.copyWith(color: du.accentText) : t.headlineMedium?.copyWith(color: du.inkTertiary)),""",
 """                    decoration: BoxDecoration(
                      color: e.sets[i].attempted ? (e.sets[i].reps! >= e.targetAt(i) ? du.accentSubtle : du.sunk) : du.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: i == nextSet && !skipped ? du.accentStrong : (e.sets[i].attempted ? du.accentLine : du.line), width: i == nextSet && !skipped ? 2 : 0.6),
                    ),
                    child: e.sets[i].attempted
                        ? (justLogged == i
                            ? Pop(key: ValueKey('p$i'), child: Text('${e.sets[i].reps}', style: t.headlineMedium?.copyWith(color: du.accentText)))
                            : Text('${e.sets[i].reps}', style: t.headlineMedium?.copyWith(color: du.accentText)))
                        : e.isPush(i)
                            ? Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(LucideIcons.arrowUp, size: 16, color: i == nextSet && !skipped ? du.accentText : du.inkTertiary),
                                Text(i == nextSet && !skipped ? 'level up' : 'push', style: t.labelSmall?.copyWith(color: i == nextSet && !skipped ? du.accentText : du.inkTertiary)),
                              ])
                            : Text(i == nextSet && !skipped ? 'now' : '·', style: i == nextSet && !skipped ? t.labelMedium?.copyWith(color: du.accentText) : t.headlineMedium?.copyWith(color: du.inkTertiary)),"""),
("""                              SizedBox(height: 76, child: FilledButton.icon(
                                onPressed: () => _log(context, session, e.target),
                                icon: const Icon(LucideIcons.check, size: 26),
                                label: Text('Hit ${e.target}$unit', style: t.headlineMedium?.copyWith(color: du.onAccent)),
                              )),""",
 """                              if (e.isPush(nextSet))
                                Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
                                  Icon(LucideIcons.arrowUp, size: 18, color: du.accentText), const SizedBox(width: 8),
                                  Expanded(child: Text('Level-up set: ${e.pushLabel}. Reach ${e.pushTarget}$unit and the level is yours today.', style: t.bodyLarge?.copyWith(color: du.accentText))),
                                ])),
                              SizedBox(height: 76, child: FilledButton.icon(
                                onPressed: () => _log(context, session, e.targetAt(nextSet)),
                                icon: Icon(e.isPush(nextSet) ? LucideIcons.arrowUp : LucideIcons.check, size: 26),
                                label: Text('Hit ${e.targetAt(nextSet)}$unit${e.isPush(nextSet) ? ' at ${e.pushLabel}' : ''}', style: t.headlineMedium?.copyWith(color: du.onAccent)),
                              )),"""),
])
t = io.open('lib/ui/session.dart', encoding='utf-8').read()
old = "onPressed: () => setState(() { fewer = true; fewerValue = seconds ? ((e.target - 5) ~/ 5) * 5 : e.target - 1; })"
assert old in t
t = t.replace(old, "onPressed: () => setState(() { fewer = true; fewerValue = seconds ? ((e.targetAt(nextSet) - 5) ~/ 5) * 5 : e.targetAt(nextSet) - 1; })")
io.open('lib/ui/session.dart', 'w', encoding='utf-8', newline='\n').write(t)

# the fewer picker's ceiling is the target of the set being logged
patch('lib/ui/session.dart', [
("""  Widget _fewerPicker(BuildContext context, Session session, SessionExercise e, bool seconds) {""",
 """  Widget _fewerPicker(BuildContext context, Session session, SessionExercise e, bool seconds) {
    final nextSet = e.sets.indexWhere((x) => !x.attempted);
    final target = nextSet < 0 ? e.target : e.targetAt(nextSet);"""),
("""    final max = (e.target - step).clamp(0, e.target);""", """    final max = (target - step).clamp(0, target);"""),
])

# ---------------- today.dart: the row and the header say what the push is
patch('lib/ui/today.dart', [
("""        '${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit, aim ${e.target}'}'""",
 """        '${e.pushRung != null ? '${e.workingSets} × ${e.lo} to ${e.hi}$unit, then a level-up set at ${e.pushLabel}' : '${e.sets.length} × ${e.atCeiling ? 'beat ${e.bestTotal} total' : '${e.lo} to ${e.hi}$unit, aim ${e.target}'}'}'"""),
("""    if (session.noRoomToPush) return 'your usual; no room to push';
    if (r > 1.05) return 'your usual, plus ${session.pushes} extra set${session.pushes == 1 ? '' : 's'}';""",
 """    if (session.noRoomToPush) return 'your usual; no room for a level-up set';
    if (r > 1.05) {
      final names = session.exercises.where((e) => e.pushRung != null).map((e) => e.exercise.name.toLowerCase()).toList();
      return 'your usual, plus a level-up try on ${names.length <= 2 ? names.join(' and ') : '${names.length} exercises'}';
    }"""),
("""        Text(e.intent == intentExtra ? '+1 set' : e.intent == intentLight ? '${(e.relative * 20).round() * 5} %' : 'usual', style: t.labelSmall?.copyWith(color: du.inkTertiary)),""",
 """        Text(e.intent == intentExtra ? 'level up' : e.intent == intentLight ? '${(e.relative * 20).round() * 5} %' : 'usual', style: t.labelSmall?.copyWith(color: du.inkTertiary)),"""),
("""        Energy.hard => 'The same exercises at your usual, plus one more set on the hardest. Working sets plus one, all at the top, levels up today.',""",
 """        Energy.hard => 'The same exercises at your usual, then a level-up set on the hardest: the next level, aim for the floor of the range. Reach it and the level is yours today.',"""),
])

# ---------------- goal editor
patch('lib/ui/goal_editor.dart', [
("""            ChoiceRow<int>(label: 'Hard day pushes', value: g.extras, options: const {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 0: 'all'}, hint: 'How many exercises get one more set on a hard day, hardest first.', onChanged: (v) => _set((x) => x.extras = v)),""",
 """            ChoiceRow<int>(label: 'Hard day level-up tries', value: g.extras, options: const {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 0: 'all'}, hint: 'How many exercises get a set at the next level on a hard day, hardest first. Reach the floor of the range and the level is yours that day.', onChanged: (v) => _set((x) => x.extras = v)),"""),
])

# ---------------- tests
patch('test/features_test.dart', [
("""    test('working sets plus one, all at the top, steps up now even when the step-up setting is 3', () {
      final s = fresh()..settings.stepUp = 3;
      ensureState(s, exerciseById['bb_squat']!).appearances = 2;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra);
      final e = session.exercises[i];
      expect(e.sets.length, e.workingSets + 1);
      final before = s.ex[e.exId]!.rung;
      var clock = t0;
      for (var k = 0; k < e.sets.length; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.hi, clock); }
      finishSession(s, session, Finish(), clock);
      expect(s.ex[e.exId]!.rung, before + 1);
      expect(session.note, contains('levels up now'));
    });

    test('an extra set that falls short is still a hit, counted once', () {
      final s = fresh()..settings.stepUp = 3;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra);
      final e = session.exercises[i];
      final before = s.ex[e.exId]!.rung;
      var clock = t0;
      for (var k = 0; k < e.workingSets; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.hi, clock); }
      logSet(session, i, e.lo, clock.add(const Duration(minutes: 2)));
      finishSession(s, session, Finish(), clock.add(const Duration(minutes: 3)));
      expect(s.ex[e.exId]!.rung, before);
      expect(s.ex[e.exId]!.topRun, 1);
    });""",
 """    test('the level-up set: working sets at the top, then the floor at the next level, steps up now even with step-up at 3', () {
      final s = fresh()..settings.stepUp = 3;
      ensureState(s, exerciseById['bb_squat']!).appearances = 2;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra);
      final e = session.exercises[i];
      expect(e.sets.length, e.workingSets + 1);
      expect(e.pushRung, e.rung + 1);
      expect(e.pushTarget, e.lo);
      expect(e.pushLabel, isNot(e.rungLabel));
      final before = s.ex[e.exId]!.rung;
      var clock = t0;
      for (var k = 0; k < e.workingSets; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.hi, clock); }
      logSet(session, i, e.pushTarget!, clock.add(const Duration(minutes: 2)));
      finishSession(s, session, Finish(), clock.add(const Duration(minutes: 3)));
      expect(s.ex[e.exId]!.rung, before + 1);
      expect(session.note, contains('levels up now'));
    });

    test('a level-up set that falls short is still a hit, counted once', () {
      final s = fresh()..settings.stepUp = 3;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra);
      final e = session.exercises[i];
      final before = s.ex[e.exId]!.rung;
      var clock = t0;
      for (var k = 0; k < e.workingSets; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.hi, clock); }
      logSet(session, i, e.pushTarget! - 1, clock.add(const Duration(minutes: 2)));
      finishSession(s, session, Finish(), clock.add(const Duration(minutes: 3)));
      expect(s.ex[e.exId]!.rung, before);
      expect(s.ex[e.exId]!.topRun, 1);
    });"""),
])
patch('test/logic_test.dart', [
("""      final extras = sess.exercises.where((e) => e.intent == intentExtra).toList();
      expect(extras.length, 1);
      expect(extras.single.sets.length, s.goal!.workingSets + 1);
      expect(extras.single.difficulty, sess.exercises.map((e) => e.difficulty).reduce(max));
      expect(sess.exercises.first.intent, intentExtra);""",
 """      final extras = sess.exercises.where((e) => e.intent == intentExtra).toList();
      expect(extras.length, s.goal!.extras);
      expect(extras.every((e) => e.sets.length == s.goal!.workingSets + 1 && e.pushRung == e.rung + 1 && e.pushTarget == e.lo), isTrue);
      expect(extras.first.difficulty, sess.exercises.map((e) => e.difficulty).reduce(max));
      expect(sess.exercises.first.intent, intentExtra);
      s.goal!.extras = 1;
      expect(build(s, energy: Energy.hard, minutes: 60).exercises.where((e) => e.intent == intentExtra).length, 1);"""),
("""      final roomy = build(s, energy: Energy.hard, minutes: 90);
      expect(roomy.pushes, 1);""",
 """      final roomy = build(s, energy: Energy.hard, minutes: 90);
      expect(roomy.pushes, greaterThanOrEqualTo(1));"""),
])
print('ok')
