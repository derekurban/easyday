import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

patch('test/logic_test.dart', [
# easy: light is neutral, working is judged
("""    test('easy sessions are never judged', () {
      final s = fresh();
      final before = {for (final e in exercises) e.id: ensureState(s, e).rung};
      final a = run(s, t0, energy: Energy.easy);
      expect(a.note, contains('Easy day'));
      for (final e in a.exercises) {
        expect(s.ex[e.exId]!.rung, before[e.exId]);
        expect(s.ex[e.exId]!.topRun, 0);
        expect(s.ex[e.exId]!.appearances, 1);
        expect(e.rung, e.exercise.loaded ? before[e.exId]! - 1 : max(0, before[e.exId]! - 1));
      }
    });""",
 """    test('easy: light exercises sit one level down and are neutral; the two working ones are judged like any other', () {
      final s = fresh();
      final before = {for (final e in exercises) e.id: ensureState(s, e).rung};
      final a = run(s, t0, energy: Energy.easy);
      final light = a.exercises.where((e) => e.intent == intentLight).toList();
      final working = a.exercises.where((e) => e.intent == intentWorking).toList();
      expect(light, isNotEmpty);
      expect(working.length, lessThanOrEqualTo(2));
      for (final e in light) {
        expect(s.ex[e.exId]!.rung, before[e.exId]);
        expect(s.ex[e.exId]!.topRun, 0);
        expect(s.ex[e.exId]!.appearances, 1);
        expect(e.rung, e.exercise.loaded ? before[e.exId]! - 1 : max(0, before[e.exId]! - 1));
        expect(e.target, max(e.lo, e.hi - 2));
      }
      for (final e in working) {
        expect(e.cost, lessThanOrEqualTo(3));
        expect(e.sets.length, s.goal!.workingSets);
        expect(s.ex[e.exId]!.rung, before[e.exId]! + 1, reason: 'the proper work counts on an easy day too');
      }
    });"""),
# energy stop
("""    test('a session stopped for energy is never judged, and the default turns easy after two stops', () {
      final s = fresh();
      run(s, t0, finish: Finish(stopReason: StopReason.energy));
      expect(s.ex['bb_squat']!.rung, 0);
      expect(s.plan!.energyDefault, Energy.normal);""",
 """    test('an energy stop with the work done still counts, and the default turns easy after two stops', () {
      final s = fresh();
      run(s, t0, finish: Finish(stopReason: StopReason.energy));
      expect(s.ex['bb_squat']!.rung, 1);
      expect(s.plan!.energyDefault, Energy.normal);"""),
# plank range
("      final r = rangeFor(s, exerciseById['plank']!, 'acc');", "      final r = rangeFor(s, exerciseById['plank']!, 1);"),
# goal test
("""      s.goal!
        ..main = const RepRange(5, 8)
        ..mains = 2
        ..accs = 2
        ..moveEvery = 0;
      rebuildRotation(s);
      expect(s.plan!.rotation.every((r) => r.type == 'lift'), isTrue);
      s.plan!.index = 0;
      final sess = build(s);
      expect(sess.exercises.where((e) => e.role == 'main').length, 2);
      expect(sess.exercises.where((e) => e.role == 'main').every((e) => e.lo == 5 && e.hi == 8), isTrue);""",
 """      s.goal!
        ..bands[0] = const RepRange(5, 8)
        ..lifts = 3
        ..workingSets = 4
        ..moveEvery = 0;
      rebuildRotation(s);
      expect(s.plan!.rotation.every((r) => r.type == 'lift'), isTrue);
      expect(s.plan!.rotation.first.patterns.length, 3);
      s.plan!.index = 0;
      final sess = build(s, minutes: 60);
      expect(sess.exercises.where((e) => e.cost >= 4).every((e) => e.lo == 5 && e.hi == 8), isTrue);
      expect(sess.exercises.where((e) => e.intent == intentWorking).every((e) => e.sets.length == 4), isTrue);"""),
("      g.acc = const RepRange(8, 12);", "      g.bands[2] = const RepRange(8, 12);"),
# energy and time group
("""    test('easy fills with nothing above cost 3, average at most 2, one rung down, sets shy of the top', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      final sess = build(s, energy: Energy.easy);
      expect(sess.exercises.every((e) => e.cost <= 3), isTrue);
      final avg = sess.exercises.fold(0, (a, e) => a + e.cost) / sess.exercises.length;
      expect(avg, lessThanOrEqualTo(2.0));
      for (final e in sess.exercises) {
        expect(e.target, max(e.lo, e.hi - 2));
        expect(e.rung, lessThan(s.ex[e.exId]!.rung + 1));
      }
    });

    test('normal has at most one exercise at cost 4 or 5', () {
      final s = fresh(template: 'gym');
      final sess = build(s);
      expect(sess.exercises.where((e) => e.cost >= 4).length, lessThanOrEqualTo(1));
    });

    test('hard puts at least half the slots at cost 4 or 5 and never an unpractised exercise there', () {
      final s = fresh(template: 'gym');
      final unpractised = build(s, energy: Energy.hard);
      expect(unpractised.exercises.where((e) => e.cost >= 4 && (s.ex[e.exId]!.appearances == 0)).length, lessThanOrEqualTo(1));
      practiseAll(s, secPerSet: 60);
      final sess = build(s, energy: Energy.hard);
      final high = sess.exercises.where((e) => e.cost >= 4).length;
      expect(high, greaterThanOrEqualTo((sess.exercises.length / 2).ceil()));
      expect(sess.exercises.every((e) => e.target == e.hi), isTrue);
    });

    test('hard does more main-lift sets than normal in the same minutes', () {
      final s = fresh(template: 'gym');
      int mainSets(Session x) => x.exercises.where((e) => e.role == 'main').fold(0, (a, e) => a + e.sets.length);
      // with the default timing seeds hard picks heavier lifts with longer sets, and still keeps its extra main sets
      practiseAll(s);
      expect(mainSets(build(s, energy: Energy.hard, minutes: 45)), greaterThanOrEqualTo(mainSets(build(s, minutes: 45))));
      // with uniform timing the difference is plain
      practiseAll(s, secPerSet: 90);
      final normal = build(s, minutes: 45);
      final hard = build(s, energy: Energy.hard, minutes: 45);
      final easy = build(s, energy: Energy.easy, minutes: 45);
      expect(mainSets(hard), greaterThan(mainSets(normal)));
      expect(mainSets(easy), lessThan(mainSets(normal)));
    });""",
 """    test('easy fills with nothing above cost 3, light everywhere but two, one rung down and shy of the top on light', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      final sess = build(s, energy: Energy.easy);
      expect(sess.exercises.every((e) => e.cost <= 3), isTrue);
      expect(sess.exercises.where((e) => e.intent == intentWorking).length, lessThanOrEqualTo(2));
      expect(sess.exercises.any((e) => e.intent == intentExtra), isFalse);
      for (final e in sess.exercises.where((e) => e.intent == intentLight)) {
        expect(e.target, max(e.lo, e.hi - 2));
        expect(e.rung, lessThan(s.ex[e.exId]!.rung + 1));
        expect(e.sets.length, lessThanOrEqualTo(3));
      }
      expect(sess.points, lessThanOrEqualTo(sess.budget + 0.01));
    });

    test('normal is working everywhere the budget allows, light past it, never over the budget', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      for (final m in [20, 35, 60, 90]) {
        final sess = build(s, minutes: m);
        expect(sess.points, lessThanOrEqualTo(sess.budget + 0.01), reason: '$m min');
        expect(sess.exercises.any((e) => e.intent == intentExtra), isFalse);
        expect(sess.exercises.where((e) => e.intent == intentWorking).every((e) => e.sets.length == s.goal!.workingSets && e.target == e.hi), isTrue);
      }
      expect(build(s, minutes: 60).exercises.every((e) => e.intent == intentWorking), isTrue);
      expect(budgetFor(s.goal!, Energy.normal, 40), 40);
      expect(budgetFor(s.goal!, Energy.normal, 90), budgetFor(s.goal!, Energy.normal, 60));
    });

    test('hard gives the costliest exercise an extra set, more with the setting, and never an unpractised heavy lift when it can avoid one', () {
      final s = fresh(template: 'gym');
      final unpractised = build(s, energy: Energy.hard);
      expect(unpractised.exercises.where((e) => e.cost >= 4 && (s.ex[e.exId]!.appearances == 0)).length, 0);
      practiseAll(s, secPerSet: 60);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      final extras = sess.exercises.where((e) => e.intent == intentExtra).toList();
      expect(extras.length, 1);
      expect(extras.single.sets.length, s.goal!.workingSets + 1);
      expect(extras.single.cost, sess.exercises.map((e) => e.cost).reduce(max));
      expect(sess.exercises.first.intent, intentExtra);
      expect(sess.exercises.every((e) => e.target == e.hi), isTrue);
      s.goal!.extras = 0;
      final all = build(s, energy: Energy.hard, minutes: 90);
      expect(all.exercises.where((e) => e.intent == intentExtra).length, greaterThan(1));
      expect(all.points, lessThanOrEqualTo(all.budget + 0.01));
    });

    test('hard spends more effort than normal, normal more than easy, in the same minutes', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 90);
      final normal = build(s, minutes: 45);
      final hard = build(s, energy: Energy.hard, minutes: 45);
      final easy = build(s, energy: Energy.easy, minutes: 45);
      expect(hard.points, greaterThan(normal.points));
      expect(easy.points, lessThan(normal.points));
      expect(sets(easy), lessThan(sets(normal)));
    });

    test('the minutes are filled: lifting, then cardio with the slack, then stretching', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      for (final m in [25, 45, 60]) {
        final sess = build(s, minutes: m);
        expect(sess.cardioMinutes, greaterThanOrEqualTo((m * s.goal!.cardioPct / 100).round()), reason: '$m');
        expect(sess.stretchMinutes, (m * s.goal!.stretchPct / 100).round(), reason: '$m');
        expect(estimateMinutes(sess), inInclusiveRange(m - 1, m + 1), reason: '$m');
      }
      s.goal!..cardioPct = 0..stretchPct = 0;
      final none = build(s, minutes: 45);
      expect(none.stretchMinutes, 0);
      expect(estimateMinutes(none), lessThanOrEqualTo(46));
    });"""),
("""      for (final m in [15, 25, 35, 45, 60, 75, 90]) {
        final x = build(s, minutes: m);
        expect(estimateMinutes(x), lessThanOrEqualTo(m), reason: '$m min');""",
 """      for (final m in [15, 25, 35, 45, 60, 75, 90]) {
        final x = build(s, minutes: m);
        expect(estimateMinutes(x), lessThanOrEqualTo(m + 1), reason: '$m min');"""),
("""    test('high-cost mains come first', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      final mains = sess.exercises.where((e) => e.role == 'main').map((e) => e.cost).toList();
      for (var i = 1; i < mains.length; i++) { expect(mains[i], lessThanOrEqualTo(mains[i - 1])); }
    });""",
 """    test('extra and working come before light, costliest first within each', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      int tier(String i) => i == intentExtra ? 0 : i == intentWorking ? 1 : 2;
      for (var i = 1; i < sess.exercises.length; i++) {
        final a = sess.exercises[i - 1], b = sess.exercises[i];
        expect(tier(b.intent), greaterThanOrEqualTo(tier(a.intent)));
        if (tier(a.intent) == tier(b.intent)) expect(b.cost, lessThanOrEqualTo(a.cost));
      }
    });"""),
])

# new judging tests appended to features_test.dart
t = io.open('test/features_test.dart', encoding='utf-8').read().rstrip()
assert t.endswith('}')
t = t[:-1] + """
  group('working level', () {
    Session startNormal(AppState s, {Energy energy = Energy.normal, int minutes = 60}) {
      final session = buildSession(s, BuildOptions(energy: energy, minutes: minutes), t0);
      startSession(s, session, t0);
      return session;
    }

    test('working sets plus one, all at the top, steps up now even when the step-up setting is 3', () {
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
    });

    test('an energy stop makes the exercise it cut a miss and leaves the rest untouched', () {
      final s = fresh();
      final session = startNormal(s);
      final a = session.exercises[0], b = session.exercises[1];
      var clock = t0;
      for (var k = 0; k < a.sets.length; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, 0, a.hi, clock); }
      logSet(session, 1, b.hi, clock.add(const Duration(minutes: 2)));
      finishSession(s, session, Finish(stopReason: StopReason.energy, stopAt: 1), clock.add(const Duration(minutes: 3)));
      expect(s.ex[a.exId]!.rung, a.rung + 1, reason: 'the finished exercise is a hit');
      expect(s.ex[b.exId]!.shortRun, 1, reason: 'the cut exercise is a miss');
      expect(s.ex[b.exId]!.rung, b.rung);
      expect(s.ex[session.exercises[2].exId]!.shortRun, 0, reason: 'never started: neutral');
    });

    test('a time stop or a plain stop that cuts the working sets is neutral', () {
      for (final reason in [StopReason.time, StopReason.none]) {
        final s = fresh();
        final session = startNormal(s);
        final b = session.exercises[1];
        logSet(session, 1, b.hi, t0.add(const Duration(minutes: 2)));
        finishSession(s, session, Finish(stopReason: reason, stopAt: 1), t0.add(const Duration(minutes: 3)));
        expect(s.ex[b.exId]!.shortRun, 0, reason: reason.name);
        expect(s.ex[b.exId]!.topRun, 0, reason: reason.name);
      }
    });

    test('a short set after a plain stop is neutral, a short set otherwise is a miss', () {
      for (final reason in [StopReason.none, null]) {
        final s = fresh();
        final session = startNormal(s);
        final a = session.exercises[0];
        var clock = t0;
        for (var k = 0; k < a.sets.length; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, 0, a.lo - 1, clock); }
        finishSession(s, session, Finish(stopReason: reason, stopAt: reason == null ? null : 1), clock);
        expect(s.ex[a.exId]!.shortRun, reason == null ? 1 : 0, reason: '${reason?.name}');
      }
    });

    test('the feel tap tunes the budget: two too-much taps at normal lower it by a tenth, two easy taps raise it', () {
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
      expect(s.goal!.budgets[1], 40);
      go(2, Feel.tooMuch);
      expect(s.goal!.budgets[1], 36);
      go(4, Feel.easy);
      go(6, Feel.easy);
      expect(s.goal!.budgets[1], greaterThan(36));
      final json = jsonEncode(s.toJson());
      expect(AppState.fromJson(jsonDecode(json)).goal!.budgets[1], s.goal!.budgets[1]);
    });

    test('old goal data with a main and an accessory range migrates to three bands and a lift count', () {
      final g = GoalConfig.fromJson({'template': 'strength', 'name': 'Get stronger', 'main': [4, 6], 'acc': [6, 10], 'mains': 3, 'accs': 1, 'moveEvery': 4});
      expect(g.bands.length, 3);
      expect(g.lifts, 4);
      expect(g.isTemplate, isTrue);
      final entry = RotationEntry.fromJson({'type': 'lift', 'name': 'Workout A', 'mains': ['squat', 'push'], 'accs': ['core']});
      expect(entry.patterns, ['squat', 'push', 'core']);
    });
  });
}
"""
io.open('test/features_test.dart', 'w', encoding='utf-8', newline='\n').write(t)
print('ok')
