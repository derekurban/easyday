import io, re
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

patch('test/logic_test.dart', [
("""    test('extra and working come before light, costliest first within each', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      int tier(String i) => i == intentExtra ? 0 : i == intentWorking ? 1 : 2;
      for (var i = 1; i < sess.exercises.length; i++) {
        final a = sess.exercises[i - 1], b = sess.exercises[i];
        expect(tier(b.intent), greaterThanOrEqualTo(tier(a.intent)));
        if (tier(a.intent) == tier(b.intent)) expect(b.cost, lessThanOrEqualTo(a.cost));
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
