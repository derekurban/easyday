p='test/logic_test.dart'
s=open(p,encoding='utf-8').read()

def rep(old,new,count=1):
    global s
    assert old in s, old[:80]
    s=s.replace(old,new,count)

rep("""      s.goal!
        ..schemes = [for (final row in strengthSchemes) List.of(row)]
        ..maxExercises = 3
        ..workingSets = 4
        ..moveEvery = 0;""","""      s.goal!
        ..bands = strengthBands()
        ..exercises = const Tri(2, 3, 3)
        ..sets = const Tri(2, 4, 4)
        ..moveEvery = 0;""")
rep("""      expect(s.ex['bb_squat']!.rung, rung);
      expect(s.goal!.isTemplate, isFalse);
    });

    test('templates round-trip and know when they are untouched', () {
      final g = GoalConfig.fromTemplate(goals['strength']!);
      expect(g.isTemplate, isTrue);
      g.schemes[2] = [lightReps];
      expect(g.isTemplate, isFalse);
    });""","""      expect(s.ex['bb_squat']!.rung, rung);
      expect(s.goal!.program, 'strength');
    });

    test('templates fill the goal; bands are tagged by difficulty and cycle in list order; a missing row borrows', () {
      final g = GoalConfig.fromTemplate(goals['strength']!);
      expect(g.program, 'strength');
      expect(g.rowFor(3), [heavyReps]);
      expect(g.rowFor(1), [lightReps]);
      g.bands = [Band(const RepRange(5, 8), [3, 2]), Band(middleReps, [3])];
      expect(g.program, isNull);
      expect(g.rangeForDifficulty(3, 0), const RepRange(5, 8));
      expect(g.rangeForDifficulty(3, 1), middleReps);
      expect(g.rangeForDifficulty(2, 1), const RepRange(5, 8));
      expect(g.rangeForDifficulty(1, 0), const RepRange(5, 8), reason: 'easy has no band of its own: borrows the nearest');
      g.fill(goals['fit']!);
      expect(g.name, 'Stay fit and mobile');
      expect(g.program, 'endurance');
      expect(g.exercises, goals['fit']!.exercises);
      final back = GoalConfig.fromJson(jsonDecode(jsonEncode(g.toJson())));
      expect(back.bands, g.bands);
      expect(back.sets, g.sets);
    });

    test('old rows per difficulty migrate to tagged bands, hard first, and old single knobs to calibrations', () {
      final g = GoalConfig.fromJson({'template': 'custom', 'name': 'Mine', 'schemes': [[[13, 18]], [[8, 12]], [[4, 7], [8, 12]]], 'maxExercises': 4, 'workingSets': 3, 'extras': 0});
      expect(g.program, 'mixed');
      expect(g.rowFor(3), [heavyReps, middleReps]);
      expect(g.exercises, const Tri(2, 4, 4));
      expect(g.sets, const Tri(2, 3, 3));
      expect(g.pushes.max, pushesMax);
    });""")
rep("""    test('normal and hard share the same list; easy keeps a subset at full sets, never more exercises', () {""",
"""    test('hard holds everything normal does; easy keeps a subset at full sets, never more exercises', () {""")
rep("""        expect(ids(hard), ids(normal), reason: '$m');
        expect(ids(normal).toSet().containsAll(ids(easy)), isTrue, reason: '$m');""",
"""        expect(ids(hard).toSet().containsAll(ids(normal)), isTrue, reason: '$m');
        expect(ids(normal).toSet().containsAll(ids(easy)), isTrue, reason: '$m');""")
rep("""        expect(normal.exercises.length, lessThanOrEqualTo(s.goal!.maxExercises), reason: '$m');
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
    });""",
"""        expect(normal.exercises.length, lessThanOrEqualTo(s.goal!.exercises.max), reason: '$m');
      }
    });

    test('the exercise calibration: the fewest on a tight day, the ideal usually, the most only on long or hard days', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 60);
      s.goal!.exercises = const Tri(1, 2, 2);
      rebuildRotation(s);
      expect(build(s, minutes: 90).exercises.length, 2);
      s.goal!.exercises = const Tri(2, 4, 8);
      rebuildRotation(s);
      expect(build(s, minutes: 120).exercises.length, greaterThan(4), reason: 'a long day grows to the most');
      expect(build(s, minutes: 120).exercises.length, lessThanOrEqualTo(8));
      expect(build(s, minutes: 120, energy: Energy.easy).exercises.length, lessThanOrEqualTo(4), reason: 'easy never grows past the ideal');
      // a usual day: the ideal list fills more than half the window, so it stays at the ideal
      practiseAll(s, secPerSet: 150);
      final usual = build(s, minutes: 45);
      expect(usual.exercises.length, 4);
      expect(usual.exercises.every((e) => e.sets.length == s.goal!.sets.ideal), isTrue);
      // a hard day grows even when the minutes alone would not
      final hard = build(s, minutes: 60, energy: Energy.hard);
      expect(hard.exercises.length + hard.exercises.fold(0, (a, e) => a + e.sets.length), greaterThan(usual.exercises.length + usual.exercises.fold(0, (a, e) => a + e.sets.length)));
      // a tight day drops exercises to the fewest before it touches sets, then sets to the fewest
      s.goal!.sets = const Tri(1, 3, 4);
      final tight = build(s, minutes: 20);
      expect(tight.exercises.length, greaterThanOrEqualTo(2));
      expect(tight.exercises.length, lessThan(4));
      final tighter = build(s, minutes: 12);
      expect(tighter.exercises.length, 2, reason: 'held at the fewest while sets can still shrink');
      expect(tighter.exercises.any((e) => e.sets.length < 3), isTrue);
      expect(tighter.exercises.every((e) => e.sets.length >= 1), isTrue);
    });""")
rep("""        expect(listed.every((e) => e.intent == intentWorking && e.sets.length == s.goal!.workingSets && e.target == e.hi), isTrue, reason: '$m');""",
"""        expect(listed.every((e) => e.intent == intentWorking && e.sets.length >= s.goal!.sets.ideal && e.sets.length <= s.goal!.sets.max && e.target == e.hi), isTrue, reason: '$m');""")
rep("""      final sess = build(s, energy: Energy.hard, minutes: 60);
      final extras = sess.exercises.where((e) => e.intent == intentExtra).toList();
      expect(extras.length, s.goal!.extras);
      for (final e in extras) {
        expect(e.nextLevel, isTrue);
        expect(e.sets.length, s.goal!.workingSets);""",
"""      final sess = build(s, energy: Energy.hard, minutes: 60);
      final extras = sess.exercises.where((e) => e.intent == intentExtra).toList();
      expect(extras.length, s.goal!.pushes.max, reason: 'a long hard day pushes the most');
      expect(build(s, energy: Energy.hard, minutes: 35).exercises.where((e) => e.intent == intentExtra).length, s.goal!.pushes.ideal, reason: 'a usual hard day pushes the ideal');
      for (final e in extras) {
        expect(e.nextLevel, isTrue);
        expect(e.sets.length, inInclusiveRange(s.goal!.sets.ideal, s.goal!.sets.max));
        expect(e.workingSets, s.goal!.sets.ideal, reason: 'only the usual sets are judged');""")
rep("""      s.goal!.extras = 1;
      expect(build(s, energy: Energy.hard, minutes: 60).exercises.where((e) => e.intent == intentExtra).length, 1);
      s.goal!.extras = 0;
      final all = build(s, energy: Energy.hard, minutes: 90);""",
"""      s.goal!.pushes = const Tri(1, 1, 1);
      expect(build(s, energy: Energy.hard, minutes: 60).exercises.where((e) => e.intent == intentExtra).length, 1);
      s.goal!.pushes = const Tri(10, 10, 10);
      final all = build(s, energy: Energy.hard, minutes: 90);""")
rep("""      s.goal!.schemes = [for (final row in mixedSchemes) List.of(row)];
      expect(todayRange(s, ex, liftIndex: 0), heavyReps);""","""      s.goal!.bands = mixedBands();
      expect(todayRange(s, ex, liftIndex: 0), heavyReps);""")
rep("""      st.repsOverride = null;
      s.goal!.schemes = [for (final row in strengthSchemes) List.of(row)];""","""      st.repsOverride = null;
      s.goal!.bands = strengthBands();""")
rep("""      s.goal!.schemes[2] = [lightReps];
      expect(st.rung, before);""","""      s.goal!.bands = enduranceBands();
      expect(st.rung, before);""")
open(p,'w',encoding='utf-8').write(s)

p='test/features_test.dart'
s=open(p,encoding='utf-8').read()
rep("""  group('calendar default', () {
    test('a packed day shortens the default minutes, a quiet one does not', () {
      final s = fresh();
      expect(defaultsFor(s, t0, busyMinutes: 7 * 60).minutes, packedDayDefault);
      expect(defaultsFor(s, t0, busyMinutes: 7 * 60).packed, isTrue);
      expect(defaultsFor(s, t0, busyMinutes: 60).minutes, minutesDefault);
      expect(defaultsFor(s, t0).packed, isFalse);
    });
  });""","""  group('calendar', () {
    test('a busy day shortens the default, a heavy one also makes it easy, a quiet one changes nothing', () {
      final s = fresh()..settings.calendar = true;
      expect(defaultsFor(s, t0, busyShare: 0.55).minutes, busyDayMinutes);
      expect(defaultsFor(s, t0, busyShare: 0.55).busy, 'short');
      expect(defaultsFor(s, t0, busyShare: 0.55).energy, Energy.normal);
      expect(defaultsFor(s, t0, busyShare: 0.75).energy, Energy.easy);
      expect(defaultsFor(s, t0, busyShare: 0.75).busy, 'easy');
      expect(defaultsFor(s, t0, busyShare: 0.2).minutes, minutesDefault);
      expect(defaultsFor(s, t0).busy, isNull);
      s.settings.busyAdjust = false;
      expect(defaultsFor(s, t0, busyShare: 0.9).busy, isNull);
      s.settings..busyAdjust = true..busyShort = 80..busyEasy = 95;
      expect(defaultsFor(s, t0, busyShare: 0.75).busy, isNull);
      expect(defaultsFor(s, t0, busyShare: 0.85).busy, 'short');
    });

    test('the day is shaped inside the awake window: overlaps merge, all-day and declined are ignored, our events are workout', () {
      final st = Settings()..awakeStart = 8 * 60..awakeEnd = 22 * 60;
      final d = DateTime(2026, 10, 16);
      DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 16, h, m);
      final events = [
        CalEvent(id: 1, begin: at(9), end: at(10, 30)),
        CalEvent(id: 2, begin: at(10), end: at(11)),              // overlaps 1: 9 to 11 is one block
        CalEvent(id: 3, begin: at(6), end: at(9)),                // clipped to 8 to 9
        CalEvent(id: 4, begin: at(0), end: at(23, 59), allDay: true),
        CalEvent(id: 5, begin: at(14), end: at(15), declined: true),
        CalEvent(id: 6, begin: at(18), end: at(19)),              // ours
        CalEvent(id: 7, begin: at(21), end: DateTime(2026, 10, 17, 1)), // clipped to 21 to 22
      ];
      final day = shapeDay(events, st, d, ourIds: {6});
      expect(day.busy, 3 * 60 + 60);
      expect(day.workout, 60);
      expect(day.free, 14 * 60 - day.busy - day.workout);
      expect(day.gaps.map((g) => '${hhmm(g.start)}-${hhmm(g.end)}').toList(), ['11:00-18:00', '19:00-21:00']);
      expect(day.busyPct, 29);
    });

    test('the suggested slot is the first free gap long enough, core hours first, the edges only with an advisory', () {
      final st = Settings();
      DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 16, h, m);
      final day = shapeDay([CalEvent(id: 1, begin: at(9), end: at(12)), CalEvent(id: 2, begin: at(12, 30), end: at(20))], st, at(0));
      final slot = suggestSlot(day, 30, at(7))!;
      expect(hhmm(slot.slot.start), '12:00');
      expect(slot.advisory, isFalse);
      final later = suggestSlot(day, 45, at(7))!;
      expect(hhmm(later.slot.start), '20:00');
      expect(later.advisory, isFalse);
      final edge = suggestSlot(day, 90, at(7))!;
      expect(hhmm(edge.slot.start), '20:00');
      expect(edge.advisory, isTrue, reason: 'runs into the last hour');
      expect(suggestSlot(day, 30, at(21, 45)), isNull);
      expect(hhmm(suggestSlot(day, 30, at(13)) !.slot.start), '20:00', reason: 'from now on');
    });

    test('the calendar event for a finished workout says what happened', () {
      final s = fresh();
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45), t0);
      startSession(s, session, t0);
      logSet(session, 0, session.exercises[0].target, t0.add(const Duration(minutes: 2)));
      finishSession(s, session, Finish(stopReason: StopReason.none, stopAt: 0), t0.add(const Duration(minutes: 20)));
      final text = workoutEventText(s, session, (e) => e.rungLabel);
      expect(text.title, startsWith('Workout A · 20 min at'));
      expect(text.description, contains(session.exercises[0].exercise.name));
    });
  });""")
rep("""      final g = GoalConfig.fromJson({'template': 'strength', 'name': 'Get stronger', 'main': [4, 6], 'acc': [6, 10], 'mains': 3, 'accs': 1, 'moveEvery': 4});
      expect(g.schemes[2], [heavyReps]);
      expect(g.maxExercises, 4);
      expect(g.program, 'strength');
      expect(g.isTemplate, isTrue);""","""      final g = GoalConfig.fromJson({'template': 'strength', 'name': 'Get stronger', 'main': [4, 6], 'acc': [6, 10], 'mains': 3, 'accs': 1, 'moveEvery': 4});
      expect(g.rowFor(3), [heavyReps]);
      expect(g.exercises.ideal, 4);
      expect(g.program, 'strength');""")
s=s.replace("import 'package:fitness/logic/builder.dart';","import 'package:fitness/logic/builder.dart';\nimport 'package:fitness/logic/calendar.dart';",1)
open(p,'w',encoding='utf-8').write(s)
print('ok')
