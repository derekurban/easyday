p='test/features_test.dart'
s=open(p,encoding='utf-8').read()
s=s.replace("import 'package:fitness/logic/calendar.dart';","import 'package:fitness/logic/calendar.dart';\nimport 'package:fitness/logic/muscles.dart';",1)
anchor="  group('calendar', () {"
assert anchor in s
new='''  group('muscles', () {
    test('sets credit the primary group fully and secondary groups by half; light sets by half of that', () {
      final s = fresh(template: 'gym');
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45), t0);
      startSession(s, session, t0);
      final e = session.exercises[0];
      for (var k = 0; k < e.sets.length; k++) { logSet(session, 0, e.target, t0.add(Duration(minutes: 2 * (k + 1)))); }
      final c = exerciseCredits(e);
      expect(c[muscleGroup(e.exercise.primary.first)], e.sets.length.toDouble());
      for (final m in e.exercise.secondary) { expect(c[muscleGroup(m)], greaterThanOrEqualTo(e.sets.length * 0.5)); }
      expect(exerciseCredits(session.exercises[1]), isEmpty, reason: 'nothing attempted yet');
      expect(exerciseCredits(session.exercises[1], planned: true), isNotEmpty);
      final light = SessionExercise.fromJson(e.toJson())..intent = intentLight;
      expect(exerciseCredits(light)[muscleGroup(e.exercise.primary.first)], e.sets.length * 0.5);
    });

    test('recent work fades over the fade days, and the strip and last-worked follow the sessions', () {
      final s = fresh(template: 'gym');
      final session = run(s, t0);
      final groups = sessionCredits(session).keys.toList();
      expect(groups, isNotEmpty);
      final g = groups.first;
      final sameDay = recentWork(s, t0.add(const Duration(hours: 2)));
      expect(sameDay[g], greaterThan(0));
      final later = recentWork(s, t0.add(const Duration(days: 3)));
      expect(later[g], lessThan(sameDay[g]!));
      expect(recentWork(s, t0.add(Duration(days: muscleFadeDays)))[g], 0);
      expect(recentWork(s, t0.add(Duration(days: muscleFadeDays)))['Chest'], 0);
      expect(lastWorked(s)[g], session.endedAt);
      final strip = dayStrip(s, g, t0.add(const Duration(days: 2)));
      expect(strip.length, 14);
      expect(strip[11], greaterThan(0));
      expect(strip[13], 0);
      expect(agoText(session.endedAt, t0.add(const Duration(days: 1))), 'yesterday');
    });

    test('the level history folds a hard day back to the user\\'s level and reads the growth in weights', () {
      final s = fresh(template: 'gym');
      final ex = exerciseById['bb_squat']!;
      run(s, t0);                                            // clean: steps up after
      run(s, t0.add(const Duration(days: 2)), energy: Energy.hard);  // the next level on the hardest, reached
      final h = levelHistory(s, ex);
      expect(h.length, 3, reason: 'two workouts and now');
      expect(h[0].stepped, isTrue);
      expect(h[1].rung, h[0].rung + 1, reason: 'the hard day is recorded at the user\\'s level, not the next');
      expect(h.last.rung, s.ex[ex.id]!.rung);
      expect(h.last.kg, greaterThan(h.first.kg!));
      final text = growthText(ex, h.first, h.last);
      expect(text, contains('levels up'));
      expect(text, contains('%'));
      expect(growthText(ex, h.last, h.last), startsWith('holding'));
    });
  });

'''
s=s.replace(anchor,new+anchor,1)
open(p,'w',encoding='utf-8').write(s)
print('ok')
