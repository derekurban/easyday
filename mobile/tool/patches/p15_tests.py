import io, re
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

# ---------------- logic_test.dart
t = io.open('test/logic_test.dart', encoding='utf-8').read()
t = t.replace('e.cost', 'e.difficulty')
io.open('test/logic_test.dart', 'w', encoding='utf-8', newline='\n').write(t)

patch('test/logic_test.dart', [
# easy test expectations
("""      for (final e in working) {
        expect(e.difficulty, lessThanOrEqualTo(3));
        expect(e.sets.length, s.goal!.workingSets);
        expect(s.ex[e.exId]!.rung, before[e.exId]! + 1, reason: 'the proper work counts on an easy day too');
      }""",
 """      for (final e in working) {
        expect(e.difficulty, lessThanOrEqualTo(2));
        expect(e.sets.length, s.goal!.workingSets);
        expect(s.ex[e.exId]!.rung, before[e.exId]! + 1, reason: 'the proper work counts on an easy day too');
      }"""),
("""      for (final e in light) {
        expect(s.ex[e.exId]!.rung, before[e.exId]);
        expect(s.ex[e.exId]!.topRun, 0);
        expect(s.ex[e.exId]!.appearances, 1);
        expect(e.rung, e.exercise.loaded ? before[e.exId]! - 1 : max(0, before[e.exId]! - 1));
        expect(e.target, max(e.lo, e.hi - 2));
      }""",
 """      for (final e in light) {
        expect(s.ex[e.exId]!.rung, before[e.exId]);
        expect(s.ex[e.exId]!.topRun, 0);
        expect(s.ex[e.exId]!.appearances, 1);
        // light: same level; loaded exercises go one expression lighter, bodyweight ones one version down for more reps
        if (e.exercise.loaded) {
          expect(e.rung, before[e.exId]);
          expect(e.expression, lighter(expressionFor(s, e.exercise)));
        } else {
          expect(e.rung, max(0, before[e.exId]! - 1));
        }
        expect(e.target, max(e.lo, e.hi - 2));
        expect(e.sets.length, max(2, s.goal!.workingSets - 1));
      }"""),
# plank range
("      final r = rangeFor(s, exerciseById['plank']!, 1);", "      final r = rangeFor(s, exerciseById['plank']!, Expression.light);"),
# goal test
("""      s.goal!
        ..bands[0] = const RepRange(5, 8)
        ..lifts = 3
        ..workingSets = 4
        ..moveEvery = 0;
      rebuildRotation(s);
      expect(s.plan!.rotation.every((r) => r.type == 'lift'), isTrue);
      expect(s.plan!.rotation.first.patterns.length, 3);
      s.plan!.index = 0;
      final sess = build(s, minutes: 60);
      expect(sess.exercises.where((e) => e.difficulty >= 4).every((e) => e.lo == 5 && e.hi == 8), isTrue);
      expect(sess.exercises.where((e) => e.intent == intentWorking).every((e) => e.sets.length == 4), isTrue);""",
 """      s.goal!
        ..reps = Expression.heavy
        ..lifts = 3
        ..workingSets = 4
        ..moveEvery = 0;
      rebuildRotation(s);
      expect(s.plan!.rotation.every((r) => r.type == 'lift'), isTrue);
      expect(s.plan!.rotation.first.patterns.length, 3);
      s.plan!.index = 0;
      final sess = build(s, minutes: 60);
      expect(sess.exercises.where((e) => e.difficulty == 3).every((e) => e.lo == 4 && e.hi == 6), isTrue);
      expect(sess.exercises.where((e) => e.intent == intentWorking).every((e) => e.sets.length == 4), isTrue);"""),
("      g.bands[2] = const RepRange(8, 12);", "      g.reps = Expression.light;"),
])

# replace the energy-and-time tests that used points and budgets
t = io.open('test/logic_test.dart', encoding='utf-8').read()
start = t.index("    test('easy fills with nothing above cost 3, light everywhere but two")
end = t.index("    test('more minutes means more sets, then more exercises")
new = """    test('energy never changes the exercises: the same list at easy, normal and hard', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 90);
      List<String> ids(Session x) => x.exercises.where((e) => !e.slot.endsWith('x')).map((e) => e.exId).toList()..sort();
      final easy = build(s, energy: Energy.easy, minutes: 60), normal = build(s, minutes: 60), hard = build(s, energy: Energy.hard, minutes: 60);
      expect(ids(easy), ids(normal));
      expect(ids(hard), ids(normal));
    });

    test('easy: light everywhere but two at working, chosen among easy and medium exercises', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      final sess = build(s, energy: Energy.easy, minutes: 60);
      final working = sess.exercises.where((e) => e.intent == intentWorking).toList();
      expect(working.length, 2);
      expect(working.every((e) => e.difficulty <= 2), isTrue);
      expect(sess.exercises.any((e) => e.intent == intentExtra), isFalse);
      for (final e in sess.exercises.where((e) => e.intent == intentLight)) {
        expect(e.target, max(e.lo, e.hi - 2));
        expect(e.sets.length, max(2, s.goal!.workingSets - 1));
      }
    });

    test('normal is working everywhere: working sets, the goal expression, aim for the top', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      for (final m in [20, 35, 60, 90]) {
        final sess = build(s, minutes: m);
        expect(sess.exercises.any((e) => e.intent == intentExtra), isFalse, reason: '$m');
        expect(sess.exercises.every((e) => e.intent == intentWorking && e.sets.length == s.goal!.workingSets && e.target == e.hi), isTrue, reason: '$m');
        for (final e in sess.exercises) { expect(e.expression, expressionFor(s, e.exercise), reason: e.exId); }
      }
    });

    test('hard: one more set on the hardest exercise, more with the setting, and the gradient holds for the same minutes', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 60);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      final extras = sess.exercises.where((e) => e.intent == intentExtra).toList();
      expect(extras.length, 1);
      expect(extras.single.sets.length, s.goal!.workingSets + 1);
      expect(extras.single.difficulty, sess.exercises.map((e) => e.difficulty).reduce(max));
      expect(sess.exercises.first.intent, intentExtra);
      s.goal!.extras = 0;
      final all = build(s, energy: Energy.hard, minutes: 90);
      expect(all.exercises.where((e) => e.intent == intentExtra).length, greaterThan(1));
      for (final m in [25, 45, 60, 90]) {
        final e = build(s, energy: Energy.easy, minutes: m), n = build(s, minutes: m), h = build(s, energy: Energy.hard, minutes: m);
        expect(h.exercises.length, greaterThanOrEqualTo(n.exercises.length), reason: '$m: hard never emptier than normal');
        expect(sets(h), greaterThanOrEqualTo(sets(n)), reason: '$m');
        expect(sets(e), lessThanOrEqualTo(sets(n)), reason: '$m');
      }
    });

    test('a tight window turns extra sets back to working before it drops an exercise', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 120);
      final hard = build(s, energy: Energy.hard, minutes: 30);
      final normal = build(s, minutes: 30);
      expect(hard.exercises.length, normal.exercises.length);
    });

    test('the minutes are filled: lifting, then cardio with the slack, then stretching; or rest when spare minutes are rest', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      for (final m in [25, 45, 60]) {
        final sess = build(s, minutes: m);
        expect(sess.cardioMinutes, greaterThanOrEqualTo((m * s.goal!.cardioPct / 100).round()), reason: '$m');
        expect(sess.stretchMinutes, (m * s.goal!.stretchPct / 100).round(), reason: '$m');
        expect(estimateMinutes(sess) + sess.spareMinutes, inInclusiveRange(m - 1, m + 1), reason: '$m');
      }
      s.goal!..cardioPct = 0..stretchPct = 0..spare = Spare.rest;
      final rest = build(s, minutes: 90);
      expect(rest.stretchMinutes, 0);
      expect(rest.cardioMinutes, 0);
      expect(rest.exercises.every((e) => !e.slot.endsWith('x')), isTrue, reason: 'no added exercises when spare minutes are rest');
      expect(rest.spareMinutes, greaterThan(0));
    });

"""
t = t[:start] + new + t[end:]
io.open('test/logic_test.dart', 'w', encoding='utf-8', newline='\n').write(t)

patch('test/logic_test.dart', [
("""    test('extra and working come before light, costliest first within each', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      int tier(String i) => i == intentExtra ? 0 : i == intentWorking ? 1 : 2;
      for (var i = 1; i < sess.exercises.length; i++) {
        final a = sess.exercises[i - 1], b = sess.exercises[i];
        expect(tier(b.intent), greaterThanOrEqualTo(tier(a.intent)));
        if (tier(a.intent) == tier(b.intent)) expect(b.difficulty, lessThanOrEqualTo(a.difficulty));
      }
    });""",
 """    test('extra and working come before light, hardest first within each', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      int tier(String i) => i == intentExtra ? 0 : i == intentWorking ? 1 : 2;
      for (var i = 1; i < sess.exercises.length; i++) {
        final a = sess.exercises[i - 1], b = sess.exercises[i];
        expect(tier(b.intent), greaterThanOrEqualTo(tier(a.intent)));
        if (tier(a.intent) == tier(b.intent)) expect(b.difficulty, lessThanOrEqualTo(a.difficulty));
      }
    });

    test('a level is strength: heavier and fewer or lighter and more at the same rung, and every rung moves every expression', () {
      final s = fresh(goal: 'strength', template: 'gym');
      final ex = exerciseById['bb_squat']!;
      final st = ensureState(s, ex);
      final heavy = loadFor(s, ex, st, st.rung, Expression.heavy), middle = loadFor(s, ex, st, st.rung, Expression.middle), light = loadFor(s, ex, st, st.rung, Expression.light);
      expect(heavy, greaterThan(middle));
      expect(middle, greaterThan(light));
      expect(rangeFor(s, ex, Expression.heavy).hi, lessThan(rangeFor(s, ex, Expression.light).lo));
      for (final expr in Expression.values) {
        for (var r = 0; r < 12; r++) {
          expect(loadFor(s, ex, st, r + 1, expr), greaterThan(loadFor(s, ex, st, r, expr)), reason: '${expr.name} rung $r');
        }
      }
      expect(rungForLoad(s, ex, st, loadFor(s, ex, st, 5, Expression.light), Expression.light), 5);
      // changing the reps the goal likes changes the weight, not the level
      final before = st.rung;
      s.goal!.reps = Expression.light;
      expect(st.rung, before);
      expect(loadFor(s, ex, st, st.rung), light);
    });"""),
])

# ---------------- features_test.dart: the budget test becomes the spare-minutes test; migration test
t = io.open('test/features_test.dart', encoding='utf-8').read()
start = t.index("    test('the feel tap tunes the budget")
end = t.index("    test('old goal data with a main and an accessory range")
new = """    test('the feel tap moves spare minutes: two too-much taps turn more exercises into cardio, two easy taps turn it back', () {
      final s = fresh();
      Session go(int day, Feel feel) {
        s.plan!.index = 0;
        final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 40), t0.add(Duration(days: day)));
        startSession(s, session, t0.add(Duration(days: day)));
        var clock = t0.add(Duration(days: day));
        for (var i = 0; i < session.exercises.length; i++) {
          for (var k = 0; k < session.exercises[i].sets.length; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, session.exercises[i].hi, clock); }
        }
        finishSession(s, session, Finish(feel: feel), clock);
        return session;
      }
      go(0, Feel.tooMuch);
      expect(s.goal!.spare, Spare.exercises);
      go(2, Feel.tooMuch);
      expect(s.goal!.spare, Spare.cardio);
      go(4, Feel.easy);
      go(6, Feel.easy);
      expect(s.goal!.spare, Spare.exercises);
      final json = jsonEncode(s.toJson());
      expect(AppState.fromJson(jsonDecode(json)).goal!.spare, s.goal!.spare);
    });

    test('a loaded exercise saved before version 4 keeps the weight the user saw', () {
      final s = fresh(goal: 'muscle');
      final ex = exerciseById['bb_squat']!;
      final st = ensureState(s, ex);
      final seen = loadFor(s, ex, st, st.rung);
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      j['version'] = 3;
      (j['ex'] as Map)['bb_squat']['baseKg'] = seen; // old data: the base was the working weight itself
      final back = AppState.fromJson(j);
      expect(loadFor(back, ex, back.ex['bb_squat']!, st.rung), closeTo(seen, stepKg(s, ex)));
    });

"""
t = t[:start] + new + t[end:]
t = t.replace("""      expect(g.bands.length, 3);
      expect(g.lifts, 4);""", """      expect(g.reps, Expression.heavy);
      expect(g.lifts, 4);""")
io.open('test/features_test.dart', 'w', encoding='utf-8', newline='\n').write(t)
print('ok')
