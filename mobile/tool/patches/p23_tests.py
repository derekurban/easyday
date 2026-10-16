import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

patch('test/logic_test.dart', [
("      expect(loadFor(s, exerciseById['goblet']!, goblet, 0, Expression.middle), 24); // twice the library start, the clamp",
 "      expect(loadFor(s, exerciseById['goblet']!, goblet, 0, middleReps), closeTo(24, stepKg(s, exerciseById['goblet']!))); // twice the library start, the clamp"),
("      final r = rangeFor(s, exerciseById['plank']!, Expression.light);", "      final r = rangeFor(s, exerciseById['plank']!, lightReps);"),
("""      s.goal!
        ..reps = Expression.heavy
        ..lifts = 3
        ..workingSets = 4
        ..moveEvery = 0;""",
 """      s.goal!
        ..schemes = [for (final row in strengthSchemes) List.of(row)]
        ..maxExercises = 3
        ..workingSets = 4
        ..moveEvery = 0;"""),
("      g.reps = Expression.light;", "      g.schemes[2] = [lightReps];"),
("""        for (final e in listed) { expect(e.expression, expressionFor(s, e.exercise), reason: e.exId); }""",
 """        for (final e in listed) { expect(e.range, todayRange(s, e.exercise), reason: e.exId); }"""),
("""      final heavy = loadFor(s, ex, st, st.rung, Expression.heavy), middle = loadFor(s, ex, st, st.rung, Expression.middle), light = loadFor(s, ex, st, st.rung, Expression.light);
      expect(heavy, greaterThan(middle));
      expect(middle, greaterThan(light));
      expect(rangeFor(s, ex, Expression.heavy).hi, lessThan(rangeFor(s, ex, Expression.light).lo));
      // the Mixed program alternates heavy and middle by workout; a card override wins over both
      s.goal!.mixed = true;
      expect(expressionFor(s, ex, liftIndex: 0), Expression.heavy);
      expect(expressionFor(s, ex, liftIndex: 1), Expression.middle);
      st.band = Expression.light;
      expect(expressionFor(s, ex, liftIndex: 0), Expression.light);
      st.band = null;
      s.goal!.mixed = false;
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
      expect(loadFor(s, ex, st, st.rung), light);""",
 """      final heavy = loadFor(s, ex, st, st.rung, heavyReps), middle = loadFor(s, ex, st, st.rung, middleReps), light = loadFor(s, ex, st, st.rung, lightReps);
      expect(heavy, greaterThan(middle));
      expect(middle, greaterThan(light));
      expect(heavyReps.hi, lessThan(lightReps.lo));
      // the Mixed program alternates heavy and middle by workout on the hard lifts; a card override wins over both
      s.goal!.schemes = [for (final row in mixedSchemes) List.of(row)];
      expect(todayRange(s, ex, liftIndex: 0), heavyReps);
      expect(todayRange(s, ex, liftIndex: 1), middleReps);
      expect(todayRange(s, ex, liftIndex: 2), heavyReps);
      st.repsOverride = lightReps;
      expect(todayRange(s, ex, liftIndex: 0), lightReps);
      st.repsOverride = const RepRange(5, 8);
      expect(todayRange(s, ex, liftIndex: 1), const RepRange(5, 8));
      st.repsOverride = null;
      s.goal!.schemes = [for (final row in strengthSchemes) List.of(row)];
      for (final band in [heavyReps, middleReps, lightReps, const RepRange(20, 25)]) {
        for (var r = 0; r < 12; r++) {
          expect(loadFor(s, ex, st, r + 1, band), greaterThan(loadFor(s, ex, st, r, band)), reason: '$band rung $r');
        }
      }
      expect(rungForLoad(s, ex, st, loadFor(s, ex, st, 5, lightReps), lightReps), 5);
      // changing the reps the goal likes changes the weight, not the level
      final before = st.rung;
      s.goal!.schemes[2] = [lightReps];
      expect(st.rung, before);
      expect(loadFor(s, ex, st, st.rung), light);"""),
("""      for (final e in sess.exercises.where((e) => e.intent == intentLight)) {
        expect(e.sets.length, max(2, s.goal!.workingSets - 1));
      }""",
 """      for (final e in sess.exercises.where((e) => e.intent == intentLight)) {
        expect(e.sets.length, s.goal!.workingSets, reason: 'easy keeps full sets and holds fewer exercises');
      }"""),
("""        expect(e.sets.length, lessThanOrEqualTo(max(2, s.goal!.workingSets - 1)));
      }
      for (final e in working) {""",
 """        expect(e.sets.length, lessThanOrEqualTo(s.goal!.workingSets));
      }
      for (final e in working) {"""),
])

# energy never changes the exercises: easy now holds fewer; hard and normal stay identical
patch('test/logic_test.dart', [
("""    test('energy never changes the exercises: the same list at easy, normal and hard, added ones included', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 90);
      List<String> ids(Session x) => x.exercises.map((e) => e.exId).toList()..sort();
      for (final m in [25, 35, 60, 90]) {
        final easy = build(s, energy: Energy.easy, minutes: m), normal = build(s, minutes: m), hard = build(s, energy: Energy.hard, minutes: m);
        expect(ids(easy), ids(normal), reason: '$m');
        expect(ids(hard), ids(normal), reason: '$m');
        expect(easy.relative, lessThan(normal.relative), reason: '$m');
        expect(normal.relative, closeTo(1, 0.1), reason: '$m'); // a spare-minute exercise may be added light
        expect(hard.relative, greaterThanOrEqualTo(normal.relative), reason: '$m');
        expect(sets(easy), lessThan(sets(normal)), reason: '$m');
        expect(sets(hard), greaterThanOrEqualTo(sets(normal)), reason: '$m');
      }
    });""",
 """    test('normal and hard share the same list; easy keeps a subset at full sets, never more exercises', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 90);
      List<String> ids(Session x) => x.exercises.map((e) => e.exId).toList()..sort();
      for (final m in [25, 35, 60, 90]) {
        final easy = build(s, energy: Energy.easy, minutes: m), normal = build(s, minutes: m), hard = build(s, energy: Energy.hard, minutes: m);
        expect(ids(hard), ids(normal), reason: '$m');
        expect(ids(normal).toSet().containsAll(ids(easy)), isTrue, reason: '$m');
        expect(easy.exercises.length, lessThanOrEqualTo(normal.exercises.length), reason: '$m');
        expect(easy.exercises.every((e) => e.sets.length == s.goal!.workingSets), isTrue, reason: '$m: full sets on easy');
        expect(easy.relative, lessThan(normal.relative), reason: '$m');
        expect(normal.relative, closeTo(1, 0.1), reason: '$m'); // a spare-minute exercise may be added light
        expect(hard.relative, greaterThanOrEqualTo(normal.relative), reason: '$m');
        expect(sets(easy), lessThanOrEqualTo(sets(normal)), reason: '$m');
        expect(sets(hard), greaterThanOrEqualTo(sets(normal)), reason: '$m');
        expect(normal.exercises.length, lessThanOrEqualTo(s.goal!.maxExercises), reason: '$m');
      }
    });

    test('the most exercises in a workout caps the list and the spare-minute growth', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 60);
      s.goal!.maxExercises = 2;
      rebuildRotation(s);
      expect(build(s, minutes: 90).exercises.length, 2);
      s.goal!.maxExercises = 8;
      rebuildRotation(s);
      expect(build(s, minutes: 120).exercises.length, greaterThan(4));
      expect(build(s, minutes: 120).exercises.length, lessThanOrEqualTo(8));
    });"""),
])

patch('test/features_test.dart', [
("""      expect(g.reps, Expression.heavy);
      expect(g.lifts, 4);""",
 """      expect(g.schemes[2], [heavyReps]);
      expect(g.maxExercises, 4);
      expect(g.program, 'strength');"""),
("""      expect(e.sets.length, max(2, e.workingSets - 1));
      expect(e.atWorkingLevel, isFalse);""",
 """      expect(e.sets.length, e.workingSets);
      expect(e.atWorkingLevel, isFalse);"""),
])
print('ok')
