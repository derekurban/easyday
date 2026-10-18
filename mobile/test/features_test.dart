import 'dart:convert';
import 'dart:io';
import 'dart:math';


import 'package:fitness/data/index.dart';
import 'package:fitness/data/library.dart';
import 'package:fitness/logic/ladder.dart';
import 'package:fitness/data/model.dart';
import 'package:fitness/logic/after.dart';
import 'package:fitness/logic/builder.dart';
import 'package:fitness/logic/calendar.dart';
import 'package:fitness/logic/muscles.dart';
import 'package:fitness/ui/muscle_figure.dart';
import 'package:fitness/logic/rotation.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 15, 9);

AppState fresh({String template = 'home_full'}) {
  final s = AppState()
    ..profile = Profile(experience: 'some', daysPerWeek: 3, createdAt: t0)
    ..goal = GoalConfig.fromTemplate(goals['muscle']!);
  final tpl = templates.firstWhere((t) => t.id == template);
  s.locations = [Location(id: 'l1', name: tpl.name, template: tpl.id, equipment: tpl.equipment.toList())];
  s.lastLocationId = 'l1';
  initPlan(s);
  return s;
}

/// Run a lifting session with every set at the target (the top), finishing cleanly.
Session run(AppState s, DateTime at, {Energy energy = Energy.normal, int minutes = 35}) {
  final session = buildSession(s, BuildOptions(energy: energy, minutes: minutes), at);
  startSession(s, session, at);
  var clock = at;
  for (var i = 0; i < session.exercises.length; i++) {
    for (var k = 0; k < session.exercises[i].sets.length; k++) {
      clock = clock.add(const Duration(seconds: 120));
      logSet(session, i, session.exercises[i].target, clock);
    }
  }
  finishSession(s, session, Finish(), clock);
  return session;
}

void main() {
  group('plain stop and skips', () {
    test('ending with no reason judges nothing and moves no default', () {
      final s = fresh();
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 60), t0);
      startSession(s, session, t0);
      logSet(session, 0, session.exercises[0].target, t0.add(const Duration(minutes: 2)));
      logSet(session, 0, session.exercises[0].target, t0.add(const Duration(minutes: 4)));
      logSet(session, 0, 3, t0.add(const Duration(minutes: 6)));
      finishSession(s, session, Finish(stopReason: StopReason.none, stopAt: 0), t0.add(const Duration(minutes: 7)));
      final st = s.ex[session.exercises[0].exId]!;
      expect(st.rung, session.exercises[0].rung);
      expect(st.shortRun, 0);
      expect(st.appearances, 1);
      expect(s.plan!.energyDefault, Energy.normal);
      expect(s.plan!.timeDefault, minutesDefault);
      expect(session.note, contains('Nothing changes'));
      expect(s.sessions.length, 1);
    });

    test('a skipped exercise is not judged even when the rest level up', () {
      final s = fresh();
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 60), t0);
      startSession(s, session, t0);
      session.skipped.add(1);
      var clock = t0;
      for (var i = 0; i < session.exercises.length; i++) {
        if (i == 1) continue;
        for (var k = 0; k < session.exercises[i].sets.length; k++) {
          clock = clock.add(const Duration(minutes: 2));
          logSet(session, i, session.exercises[i].target, clock);
        }
      }
      finishSession(s, session, Finish(), clock);
      expect(s.ex[session.exercises[0].exId]!.rung, session.exercises[0].rung + 1);
      expect(s.ex[session.exercises[1].exId]!.rung, session.exercises[1].rung);
      expect(s.ex[session.exercises[1].exId]!.appearances, 0);
    });
  });

  group('circuit', () {
    test('timing credits each gap to the exercise whose set ended it', () {
      final s = fresh();
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 60, circuit: true), t0);
      startSession(s, session, t0);
      expect(session.circuit, isTrue);
      final a = session.exercises[0], b = session.exercises[1];
      final before = {a.exId: s.ex[a.exId]!.secPerSet, b.exId: s.ex[b.exId]!.secPerSet};
      var clock = t0;
      // round-robin: a, b, a, b ... with 100 s before every a-set and 300 s before every b-set
      for (var r = 0; r < 2; r++) {
        clock = clock.add(const Duration(seconds: 100)); logSet(session, 0, a.target, clock);
        clock = clock.add(const Duration(seconds: 300)); logSet(session, 1, b.target, clock);
      }
      finishSession(s, session, Finish(stopReason: StopReason.none), clock);
      expect(s.ex[a.exId]!.secPerSet, lessThan(before[a.exId]!));
      expect(s.ex[b.exId]!.secPerSet, greaterThan(before[b.exId]!));
    });
  });

  group('closure', () {
    test('a finished workout closes the day until tomorrow or until the user continues', () {
      final s = fresh();
      expect(finishedToday(s, t0), isFalse);
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 35), t0);
      startSession(s, session, t0);
      finishSession(s, session, Finish(stopReason: StopReason.none), t0.add(const Duration(minutes: 20)));
      expect(finishedToday(s, t0.add(const Duration(hours: 5))), isTrue);
      expect(continuedToday(s, t0.add(const Duration(hours: 5))), isFalse);
      s.plan!.continuedOn = t0.add(const Duration(hours: 5));
      expect(continuedToday(s, t0.add(const Duration(hours: 6))), isTrue);
      expect(finishedToday(s, t0.add(const Duration(days: 1))), isFalse);
      expect(continuedToday(s, t0.add(const Duration(days: 1))), isFalse);
    });
  });

  group('muscles', () {
    test('sets credit each primary muscle fully and each secondary muscle by half; light sets by half of that', () {
      final s = fresh(template: 'gym');
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45), t0);
      startSession(s, session, t0);
      final e = session.exercises[0];
      for (var k = 0; k < e.sets.length; k++) { logSet(session, 0, e.target, t0.add(Duration(minutes: 2 * (k + 1)))); }
      final c = exerciseCredits(e);
      for (final m in e.exercise.primary) { expect(c[m], e.sets.length.toDouble(), reason: m); }
      for (final m in e.exercise.secondary.where((m) => !e.exercise.primary.contains(m))) { expect(c[m], e.sets.length * 0.5, reason: m); }
      expect(exerciseCredits(session.exercises[1]), isEmpty, reason: 'nothing attempted yet');
      expect(exerciseCredits(session.exercises[1], planned: true), isNotEmpty);
      final light = SessionExercise.fromJson(e.toJson())..intent = intentLight;
      expect(exerciseCredits(light)[e.exercise.primary.first], e.sets.length * 0.5);
      // the work goes to the muscles doing it: a row credits the upper back fully and each helper by half
      final row = SessionExercise.fromJson(e.toJson())..exId = 'bb_row';
      final n = e.sets.length.toDouble();
      expect(exerciseCredits(row), {'upper back': n, 'lats': n / 2, 'biceps': n / 2, 'rear shoulders': n / 2});
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
      expect(recentWork(s, t0.add(Duration(days: muscleFadeDays)))['chest'], 0);
      expect(recentWork(s, t0).keys, trackedMuscles);
      expect(lastWorked(s)[g], session.endedAt);
      final strip = dayStrip(s, g, t0.add(const Duration(days: 2)));
      expect(strip.length, 14);
      expect(strip[11], greaterThan(0));
      expect(strip[13], 0);
      expect(agoText(session.endedAt, t0.add(const Duration(days: 1))), 'yesterday');
    });

    test('a workout highlights its exercises\' primary muscles strong and secondary ones light, by muscle', () {
      final s = fresh(template: 'gym');
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45), t0);
      final m = workoutMuscles(session);
      final first = session.exercises[0].exercise;
      expect(m[first.primary.first], primaryStrength);
      final secondaryOnly = session.exercises.expand((e) => e.exercise.secondary).where((g) => !session.exercises.any((e) => e.exercise.primary.contains(g)));
      for (final g in secondaryOnly) { expect(m[g], secondaryStrength, reason: g); }
      for (final g in m.keys) { expect(muscleNames, contains(g), reason: g); }
    });

    test('a strength draws at one of three accent steps: main full, helping the middle one, a trace the lightest', () {
      expect(muscleStepOpacity(0), 0);
      expect(muscleStepOpacity(0.05), muscleSteps[0]);
      expect(muscleStepOpacity(1 / 3), muscleSteps[0]);
      expect(muscleStepOpacity(secondaryStrength), muscleSteps[1]);
      expect(muscleStepOpacity(0.7), muscleSteps[2]);
      expect(muscleStepOpacity(primaryStrength), muscleSteps[2]);
      expect(muscleStepOpacity(3), muscleSteps[2]);
    });

    test('the level history folds a hard day back to the user\'s level and reads the growth in weights', () {
      final s = fresh(template: 'gym');
      final ex = exerciseById['bb_squat']!;
      run(s, t0);                                            // clean: steps up after
      s.plan!.index = 0;                                     // the same workout again
      run(s, t0.add(const Duration(days: 2)), energy: Energy.hard);  // the next level on the hardest, reached
      final h = levelHistory(s, ex);
      expect(h.length, 3, reason: 'two workouts and now');
      expect(h[0].stepped, isTrue);
      expect(h[1].rung, h[0].rung + 1, reason: 'the hard day is recorded at the user\'s level, not the next');
      expect(h.last.rung, s.ex[ex.id]!.rung);
      expect(h.last.kg, greaterThan(h.first.kg!));
      final text = growthText(ex, h.first, h.last);
      expect(text, contains('levels up'));
      expect(text, contains('%'));
      expect(growthText(ex, h.last, h.last), startsWith('holding'));
    });
  });

  group('body map', () {
    Set<String> mapNames() {
      final meta = jsonDecode(File('assets/muscle/flat.json').readAsStringSync()) as Map<String, dynamic>;
      final names = <String>{};
      for (final key in ['male_front', 'male_back', 'female_front', 'female_back']) {
        final plates = (meta['maps'][key]['plates'] as List).cast<Map<String, dynamic>>();
        expect(plates, isNotEmpty, reason: key);
        for (final p in plates) { names.add(p['name'] as String); }
      }
      return names;
    }

    test('every plate is named with a standard muscle name, and every name but the shins folds onto a group', () {
      final names = mapNames();
      expect(names, unorderedEquals(muscleNames), reason: 'the map shows every muscle and only those');
      for (final n in names.where((n) => n != 'shins')) { expect(muscleGroups, contains(muscleGroup(n)), reason: n); }
      expect(File('assets/muscle/male_front.png').existsSync(), isTrue);
      expect(File('assets/muscle/female_back_ids.png').existsSync(), isTrue);
    });

    test('exercises are tagged only with standard muscle names, and every muscle on the map but the shins can light up', () {
      final tagged = <String>{};
      for (final e in exercises) {
        expect(e.primary, isNotEmpty, reason: e.id);
        for (final m in [...e.primary, ...e.secondary]) { expect(muscleNames, contains(m), reason: '${e.id}: $m'); tagged.add(m); }
      }
      for (final n in mapNames().where((n) => n != 'shins')) { expect(tagged, contains(n), reason: 'no exercise works $n'); }
      expect(exerciseById['hip_abduction']!.primary, ['outer hips']);
      expect(exerciseById['face_pull']!.primary, ['rear shoulders']);
      expect(exerciseById['lat_raise']!.primary, ['side shoulders']);
      expect(exerciseById['russian_twist']!.primary, ['obliques']);
    });
  });

  group('calendar', () {
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
  });

  group('how-to per level', () {
    test('bodyweight levels have their own text or a folded note, loaded ones keep one text', () {
      final pushup = exerciseById['pushup']!;
      expect(howAt(pushup, 0), contains('wall'));
      expect(howAt(pushup, 3), pushup.how);
      expect(howAt(pushup, 4), contains('Feet up'));
      final dips = exerciseById['dips']!;
      expect(howAt(dips, 3), contains('2 seconds at the bottom'));
      final band = exerciseById['band_row']!;
      expect(howAt(band, 2), contains('heavy band'));
      final squat = exerciseById['bb_squat']!;
      expect(howAt(squat, 5), squat.how);
      for (final e in exercises.where((e) => !e.loaded)) {
        for (var r = 0; r < e.ladder!.variants.length; r++) { expect(howAt(e, r).trim(), isNotEmpty, reason: '${e.id} $r'); }
      }
    });
  });

  group('level trend', () {
    test('reports the net level change per exercise over 30 days', () {
      final s = fresh();
      final session = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 35), t0);
      startSession(s, session, t0);
      var clock = t0;
      for (var i = 0; i < session.exercises.length; i++) {
        for (var k = 0; k < session.exercises[i].sets.length; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, session.exercises[i].target, clock); }
      }
      finishSession(s, session, Finish(), clock);
      final trend = levelTrend(s, clock);
      expect(trend[session.exercises.first.exId], 1);
    });
  });

  group('indexes', () {
    test('every exercise lands in a named group under every index', () {
      for (final ix in ExerciseIndex.values) {
        final order = indexOrder(ix);
        for (final e in exercises) {
          expect(order, contains(indexGroup(e, ix)), reason: '${e.id} under ${ix.name}');
        }
      }
    });
    test('muscle groups fold the twenty muscle names into eleven', () {
      expect(muscleGroup('lats'), 'Back');
      expect(muscleGroup('quads'), 'Quads');
      expect(muscleGroup('lower back'), 'Core');
      expect(muscleGroup('rear shoulders'), 'Shoulders');
      expect(muscleGroup('obliques'), 'Core');
      expect(muscleGroup('outer hips'), 'Glutes');
      expect(muscleGroup('shins'), 'Other');
      expect(muscleTitle('front shoulders'), 'Front shoulders');
      expect(indexGroup(exerciseById['pushup']!, ExerciseIndex.muscle), 'Chest');
      expect(indexGroup(exerciseById['pushup']!, ExerciseIndex.region), 'Upper body');
      expect(indexGroup(exerciseById['pushup']!, ExerciseIndex.equipment), 'Bodyweight');
      expect(indexGroup(exerciseById['pushup']!, ExerciseIndex.progression), 'By version');
    });
    test('grouping keeps heading order and never lists an exercise twice', () {
      final groups = groupBy(exercises, ExerciseIndex.muscle);
      expect(groups.map((g) => g.key).toList(), muscleGroups.where((g) => groups.any((x) => x.key == g)).toList());
      expect(groups.fold(0, (n, g) => n + g.value.length), exercises.length);
    });
    test('the index is a setting that round-trips', () {
      final s = fresh()..settings.index = ExerciseIndex.equipment;
      final back = AppState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.settings.index, ExerciseIndex.equipment);
    });
  });

  group('working level', () {
    Session startNormal(AppState s, {Energy energy = Energy.normal, int minutes = 60}) {
      final session = buildSession(s, BuildOptions(energy: energy, minutes: minutes), t0);
      startSession(s, session, t0);
      return session;
    }

    test('hard: the floor on every set at the next level makes it yours today, even with step-up at 3', () {
      final s = fresh()..settings.stepUp = 3;
      ensureState(s, exerciseById['bb_squat']!).appearances = 2;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra);
      final e = session.exercises[i];
      expect(e.nextLevel, isTrue);
      expect(e.sets.length, greaterThanOrEqualTo(e.workingSets), reason: 'a long hard day may add a set; only the usual sets are judged');
      final before = s.ex[e.exId]!.rung;
      expect(e.rung, before + 1);
      var clock = t0;
      for (var k = 0; k < e.workingSets; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.lo, clock); }
      finishSession(s, session, Finish(), clock.add(const Duration(minutes: 3)));
      expect(s.ex[e.exId]!.rung, before + 1);
      expect(session.note, contains('levels up now'));
    });

    test('one rep short at the next level is read by its worth: within the range at your level, so it holds', () {
      final s = fresh()..settings.stepUp = 3;
      final session = startNormal(s, energy: Energy.hard);
      final i = session.exercises.indexWhere((e) => e.intent == intentExtra && e.exercise.loaded);
      final e = session.exercises[i];
      final before = s.ex[e.exId]!.rung;
      final worth = repsEquivalent(e.lo - 1, e.loadKg!, e.usualLoadKg!);
      expect(worth, inInclusiveRange(e.lo.toDouble(), e.hi.toDouble()), reason: 'one short at ${e.loadKg} is worth $worth at ${e.usualLoadKg}');
      var clock = t0;
      for (var k = 0; k < e.workingSets; k++) { clock = clock.add(const Duration(minutes: 2)); logSet(session, i, e.lo - 1, clock); }
      finishSession(s, session, Finish(), clock.add(const Duration(minutes: 3)));
      expect(s.ex[e.exId]!.rung, before);
      expect(s.ex[e.exId]!.shortRun, 0);
      expect(s.ex[e.exId]!.topRun, 0);
      expect(session.note, contains('holds'));
    });

    test('an easy day lifts 85 % of the usual, a set fewer, and is neutral', () {
      final s = fresh();
      final session = startNormal(s, energy: Energy.easy);
      final e = session.exercises.firstWhere((x) => x.intent == intentLight && x.exercise.loaded);
      expect(e.rung, s.ex[e.exId]!.rung);
      expect(e.loadKg, closeTo(e.usualLoadKg! * easyShare, stepKg(s, e.exercise)));
      expect(e.sets.length, e.workingSets);
      expect(e.atWorkingLevel, isFalse);
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

    test('the feel tap moves spare minutes: two too-much taps turn more exercises into cardio, two easy taps turn it back', () {
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
      final s = fresh();
      final ex = exerciseById['bb_squat']!;
      final st = ensureState(s, ex);
      final seen = loadFor(s, ex, st, st.rung);
      final j = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
      j['version'] = 3;
      (j['ex'] as Map)['bb_squat']['baseKg'] = seen; // old data: the base was the working weight itself
      final back = AppState.fromJson(j);
      expect(loadFor(back, ex, back.ex['bb_squat']!, st.rung), closeTo(seen, stepKg(s, ex)));
    });

    test('old goal data with a main and an accessory range migrates to three bands and a lift count', () {
      final g = GoalConfig.fromJson({'template': 'strength', 'name': 'Get stronger', 'main': [4, 6], 'acc': [6, 10], 'mains': 3, 'accs': 1, 'moveEvery': 4});
      expect(g.rowFor(3), [heavyReps]);
      expect(g.exercises.ideal, 4);
      expect(g.program, 'strength');
      final entry = RotationEntry.fromJson({'type': 'lift', 'name': 'Workout A', 'mains': ['squat', 'push'], 'accs': ['core']});
      expect(entry.patterns, ['squat', 'push', 'core']);
    });
  });
}
