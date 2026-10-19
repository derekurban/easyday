# The muscle tests become strain points tests (MUSCLE_MAP.md), with the builder's picks by strain points.
import pathlib

p = pathlib.Path('test/features_test.dart')
t = p.read_bytes().decode().replace('\r\n', '\n')

t = t.replace("""import 'package:easyday/logic/muscles.dart';
""", """import 'package:easyday/logic/levels.dart';
import 'package:easyday/logic/muscle_map.dart';
import 'package:easyday/logic/person.dart';
""", 1)

start = t.index("  group('muscles', () {\n")
end = t.index("    test('the level history folds a hard day back")
new = r"""  group('muscle map', () {
    /// A finished workout of the given exercises and set counts, every set attempted unless [light] or [planned] say.
    Session logged(AppState s, DateTime at, Map<String, int> exSets, {bool light = false}) {
      final x = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45), at);
      final template = x.exercises.first;
      x.exercises = [
        for (final e in exSets.entries)
          SessionExercise.fromJson(template.toJson())
            ..exId = e.key
            ..slot = e.key
            ..intent = light ? intentLight : intentWorking
            ..sets = List.generate(e.value, (_) => SetLog(reps: 8, at: at)),
      ];
      x.startedAt = at;
      x.endedAt = at;
      s.sessions.add(x);
      return x;
    }

    test('strain points from set: 0.20 on each primary muscle, 0.10 on each helper, half for a light set', () {
      final row = exerciseById['bb_row']!;
      expect(strainPointsFromSet(row).byMuscle, {'upper back': 0.20, 'lats': 0.10, 'biceps': 0.10, 'rear shoulders': 0.10});
      expect(strainPointsFromSet(row, light: true)['upper back'], closeTo(0.10, 1e-9));
      expect(strainPointsFromSets(row, 3)['upper back'], closeTo(0.60, 1e-9));
      expect(strainPointsFromSets(row, 3)['lats'], closeTo(0.30, 1e-9));
    });

    test('strain points from exercise count the attempted sets, or every set when planned', () {
      final s = fresh(template: 'gym');
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45), t0);
      startSession(s, session, t0);
      final e = session.exercises[0];
      logSet(session, 0, e.target, t0.add(const Duration(minutes: 2)));
      final m = e.exercise.primary.first;
      expect(strainPointsFromExercise(e)[m], closeTo(0.20, 1e-9));
      expect(strainPointsFromExercise(e, planned: true)[m], closeTo(min(1.0, 0.20 * e.sets.length), 1e-9));
      expect(strainPointsFromExercise(session.exercises[1]).isEmpty, isTrue, reason: 'nothing attempted yet');
    });

    test('strain points from workout: a muscle tops out at 1.00, helping at 0.50', () {
      final s = fresh(template: 'gym');
      // bench and flies: six sets on the chest, still 1.00
      final x = logged(s, t0, {'bb_bench': 3, 'db_fly': 3, 'ohp': 4});
      final p = strainPointsFromWorkout(x);
      expect(p['chest'], 1.0);
      // the front shoulders: main in four sets of overhead press (0.80), helping on bench and flies, which adds at most 0.50
      expect(p['front shoulders'], 1.0);
      // the triceps only help: seven sets would be 0.70, but helping tops out at 0.50
      expect(p['triceps'], closeTo(0.50, 1e-9));
      for (final m in p.muscles) { expect(p[m], lessThanOrEqualTo(strainPointsMax), reason: m); }
      expect(strainPointsFromWorkout(Session.fromJson(x.toJson())..type = 'move').isEmpty, isTrue);
    });

    test('strain point decay takes a third a day, so a muscle steps down one shade a day', () {
      final s = fresh(template: 'gym');
      logged(s, t0, {'bb_bench': 5});
      final map = MuscleMap(s);
      expect(map.currentStrainPoints(t0.add(const Duration(hours: 3)))['chest'], 1.0);
      expect(map.currentStrainPoints(t0.add(const Duration(hours: 3))).shade('chest'), 3);
      expect(map.currentStrainPoints(t0.add(const Duration(days: 1)))['chest'], closeTo(2 / 3, 1e-9));
      expect(map.currentStrainPoints(t0.add(const Duration(days: 1))).shade('chest'), 2);
      expect(map.currentStrainPoints(t0.add(const Duration(days: 2))).shade('chest'), 1);
      expect(map.currentStrainPoints(t0.add(const Duration(days: 3))).strainFree('chest'), isTrue);
      expect(map.strainFreeOn('chest', t0), DateTime(2026, 10, 18));
      expect(map.currentStrainPoints(t0.subtract(const Duration(hours: 1))).isEmpty, isTrue, reason: 'nothing before the workout');
    });

    test('a workout adds to what is left, capped at 1.00: two chest days in a row start the three days again', () {
      final s = fresh(template: 'gym');
      logged(s, t0, {'bb_bench': 5});
      logged(s, t0.add(const Duration(days: 1)), {'bb_bench': 3});
      final map = MuscleMap(s);
      expect(map.currentStrainPoints(t0.add(const Duration(days: 1, hours: 2)))['chest'], 1.0);
      expect(map.strainFreeOn('chest', t0.add(const Duration(days: 1, hours: 2))), DateTime(2026, 10, 19));
      // three sets alone: 0.60, strain-free in two days
      final s2 = fresh(template: 'gym');
      logged(s2, t0, {'bb_bench': 3});
      expect(MuscleMap(s2).strainFreeOn('chest', t0), DateTime(2026, 10, 17));
      // three light sets: 0.30, strain-free the next day
      final s3 = fresh(template: 'gym');
      logged(s3, t0, {'bb_bench': 3}, light: true);
      expect(MuscleMap(s3).currentStrainPoints(t0)['chest'], closeTo(0.30, 1e-9));
      expect(MuscleMap(s3).strainFreeOn('chest', t0), DateTime(2026, 10, 16));
    });

    test('the strain points timeline has a day for every day, the workouts marked, and agrees with current strain points', () {
      final s = fresh(template: 'gym');
      logged(s, t0, {'bb_bench': 5});
      logged(s, t0.add(const Duration(days: 2)), {'bb_squat': 3});
      final map = MuscleMap(s);
      final to = t0.add(const Duration(days: 4));
      final days = map.strainPointsTimeline(t0.subtract(const Duration(days: 2)), to);
      expect(days.length, 7);
      expect(days.map((d) => d.workouts.length).toList(), [0, 0, 1, 0, 1, 0, 0]);
      expect(days[2].workouts.single.points['chest'], 1.0);
      for (final d in days) {
        final end = DateTime(d.day.year, d.day.month, d.day.day, 23, 59);
        for (final m in trackedMuscles) { expect(d.points[m], closeTo(map.currentStrainPoints(end)[m], 1e-9), reason: '${d.day} $m'); }
      }
      expect(days[0].points.isEmpty, isTrue);
      expect(map.lastWorked()['quads'], t0.add(const Duration(days: 2)));
      expect(map.lastWorked()['calves'], t0.add(const Duration(days: 2)), reason: 'helping counts as worked');
      expect(map.lastWorked()['abs'], isNull);
      expect(agoText(t0, t0.add(const Duration(days: 1))), 'yesterday');
      expect(dayText(DateTime(2026, 10, 17), t0), 'Saturday');
      expect(dayText(DateTime(2026, 10, 16), t0), 'tomorrow');
    });

    test('three shades, each an exact third: low, medium, high', () {
      expect(strainShade(0), 0);
      expect(strainShade(0.01), 1);
      expect(strainShade(1 / 3), 1);
      expect(strainShade(0.34), 2);
      expect(strainShade(2 / 3), 2);
      expect(strainShade(1 - 1 / 3 - 1 / 3 + 1 / 3), 2, reason: 'float sums land in their third');
      expect(strainShade(0.67), 3);
      expect(strainShade(1), 3);
      expect(strainOpacity(0), 0);
      expect(strainOpacity(0.2), strainShadeOpacity[0]);
      expect(strainOpacity(0.6), strainShadeOpacity[1]);
      expect(strainOpacity(1), strainShadeOpacity[2]);
      expect(strainPointsText(2 / 3), '0.67');
    });

    test('the builder picks exercises whose primary muscles are strain-free, and a strained pattern sits out', () {
      final s = fresh(template: 'gym');
      final first = run(s, t0);
      final day1 = t0.add(const Duration(days: 1));
      s.plan!.index = first.itemIndex;                       // the same workout again, the next day
      final again = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45), day1);
      final current = MuscleMap(s).currentStrainPoints(day1);
      expect(current.isEmpty, isFalse);
      for (final e in again.exercises) {
        expect(e.exercise.primary.every(current.strainFree), isTrue, reason: '${e.exId} works ${e.exercise.primary} with $current');
      }
      final squatFirst = first.exercises.any((e) => e.pattern == 'squat');
      if (squatFirst) {
        expect(again.satOut['squat'], isNotNull, reason: 'every squat works the quads, still carrying strain');
        expect(again.exercises.any((e) => e.pattern == 'squat'), isFalse);
      }
      // the user's own pick stands, strain or not
      final pushFirst = first.exercises.firstWhere((e) => e.pattern == 'push');
      final picked = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45, picks: {pushFirst.slot: pushFirst.exId}), day1);
      expect(picked.exercises.any((e) => e.exId == pushFirst.exId), isTrue);
      // two days on everything is strain-free again, and the same exercises come back
      final day3 = t0.add(const Duration(days: 3));
      final later = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45), day3);
      expect(MuscleMap(s).currentStrainPoints(day3).isEmpty, isTrue);
      expect(later.satOut, isEmpty);
      for (final e in first.exercises.where((e) => !e.slot.endsWith('x'))) {
        expect(later.exercises.any((x) => x.exId == e.exId), isTrue, reason: '${e.exId} is practised and strain-free');
      }
    });

"""
t = t[:start] + new + t[end:]
p.write_bytes(t.replace('\n', '\r\n').encode())
