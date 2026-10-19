import 'dart:convert';
import 'dart:math';

import 'package:easyday/data/index.dart';
import 'package:easyday/data/library.dart';
import 'package:easyday/data/model.dart';
import 'package:easyday/data/store.dart';
import 'package:easyday/logic/after.dart';
import 'package:easyday/logic/builder.dart';
import 'package:easyday/logic/ladder.dart';
import 'package:easyday/logic/person.dart';
import 'package:easyday/logic/selection.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 14, 9);

AppState fresh({String goal = 'muscle', String experience = 'some', String template = 'home_full', int days = 3}) {
  final s = AppState()
    ..profile = Profile(experience: experience, daysPerWeek: days, createdAt: t0)
    ..goal = GoalConfig.fromTemplate(goals[goal]!);
  final tpl = templates.firstWhere((t) => t.id == template);
  s.locations = [Location(id: 'l1', name: tpl.name, template: tpl.id, equipment: tpl.equipment.toList())];
  s.lastLocationId = 'l1';
  s.plan = Plan();
  return s;
}

/// The muscle the squat is chosen for, so a test can ask for it again by hand the way the user would.
const quads = ['quads'];
const chest = ['chest'];

Session build(AppState s, {Energy energy = Energy.normal, int minutes = 35, DateTime? at, List<String> muscles = const []}) =>
    buildSession(s, BuildOptions(energy: energy, minutes: minutes, muscles: muscles, liftInstead: true), at ?? t0);

/// Run a lifting session with the same reps in every set of every exercise (or per exercise by id).
Session run(AppState s, DateTime at, {Energy energy = Energy.normal, int minutes = 35, int? reps, Map<String, int> repsBy = const {},
    bool hitTop = true, Finish? finish, int gapSeconds = 120, Map<String, int> rungOverrides = const {}, List<String> muscles = const []}) {
  final session = buildSession(s, BuildOptions(energy: energy, minutes: minutes, rungOverrides: rungOverrides, muscles: muscles, liftInstead: true), at);
  startSession(s, session, at);
  var clock = at;
  for (var i = 0; i < session.exercises.length; i++) {
    final e = session.exercises[i];
    for (var k = 0; k < e.sets.length; k++) {
      clock = clock.add(Duration(seconds: gapSeconds));
      final r = repsBy[e.exId] ?? reps ?? (hitTop ? e.target : e.lo);
      logSet(session, i, r, clock);
    }
  }
  finishSession(s, session, finish ?? Finish(), clock);
  return session;
}

int sets(Session x) => x.exercises.fold(0, (a, e) => a + e.sets.length);

void practiseAll(AppState s, {double? secPerSet}) {
  for (final e in exercises) {
    final st = ensureState(s, e)..appearances = 2;
    if (secPerSet != null) st.secPerSet = secPerSet;
  }
}

void main() {
  group('library', () {
    test('every exercise is either loaded or on a ladder, with a cost from 1 to 5 and a unique id', () {
      final ids = <String>{};
      for (final e in exercises) {
        expect(ids.add(e.id), isTrue, reason: 'duplicate ${e.id}');
        expect(e.difficulty, inInclusiveRange(1, 5), reason: e.id);
        expect(e.loaded ? e.startKg != null && e.stepKg != null : e.ladder!.variants.length >= 3, isTrue, reason: e.id);
        expect(e.primary, isNotEmpty, reason: e.id);
        for (final need in e.needs) { for (final item in need) { expect(equipment.containsKey(item), isTrue, reason: '${e.id} needs $item'); } }
        if (e.ladder != null) {
          expect(e.ladder!.start.length, 3, reason: e.id);
          for (final r in e.ladder!.start) { expect(r, lessThan(e.ladder!.variants.length), reason: e.id); }
          for (final g in e.ladder!.loadGear) { expect(equipment.containsKey(g), isTrue, reason: '${e.id} gear $g'); }
        }
      }
      expect(exercises.length, greaterThanOrEqualTo(120));
    });

    test('every muscle group has a loaded option, and all but the forearms a bodyweight option', () {
      for (final g in muscleGroups) {
        final list = exercises.where((e) => primaryGroups(e).contains(g));
        if (g != 'Forearms') expect(list.any((e) => !e.loaded), isTrue, reason: g);
        expect(list.any((e) => e.loaded), isTrue, reason: g);
      }
    });
  });

  group('ladder', () {
    test('a normal session with every set at the top steps up next time (step up = 1)', () {
      final s = fresh();
      final a = run(s, t0);
      expect(a.type, 'lift');
      expect(a.note, contains('levels up'));
      for (final e in a.exercises) {
        expect(s.ex[e.exId]!.rung, e.rung + 1, reason: e.exId);
      }
    });

    test('step up waits for N sessions in a row when the setting is raised', () {
      final s = fresh()..settings.stepUp = 3;
      run(s, t0);
      final before = s.ex['bb_squat']!.rung;
      run(s, t0.add(const Duration(days: 2)), repsBy: {'bb_squat': 12}, muscles: quads);
      expect(s.ex['bb_squat']!.rung, before);
      expect(s.ex['bb_squat']!.topRun, 2);
      run(s, t0.add(const Duration(days: 4)), repsBy: {'bb_squat': 12}, muscles: quads);
      expect(s.ex['bb_squat']!.rung, before + 1);
    });

    test('a set below the bottom holds, two in a row step down (step down = 2)', () {
      final s = fresh();
      run(s, t0, reps: 5); // below 8
      final squat = s.ex['bb_squat']!;
      final r0 = squat.rung;
      expect(squat.shortRun, 1);
      run(s, t0.add(const Duration(days: 2)), reps: 5, muscles: quads);
      expect(s.ex['bb_squat']!.rung, r0 - 1);
    });

    test('reps between bottom and top keep the rung and reset streaks', () {
      final s = fresh();
      run(s, t0, reps: 8); // the heavy band is 6 to 10 on the muscle goal
      final st = s.ex['bb_squat']!;
      expect(st.rung, 0);
      expect(st.topRun, 0);
      expect(st.shortRun, 0);
    });

    test('easy: light exercises sit one level down and are neutral; the two working ones are judged like any other', () {
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
        // light: same level; loaded exercises lift a share of the usual weight, bodyweight ones go one version down
        if (e.exercise.loaded) {
          expect(e.rung, before[e.exId]);
          expect(e.loadKg, lessThan(e.usualLoadKg!));
          expect(e.loadKg, closeTo(e.usualLoadKg! * easyShare, stepKg(s, e.exercise)));
        } else {
          expect(e.rung, max(0, before[e.exId]! - 1));
        }
        expect(e.sets.length, lessThanOrEqualTo(s.goal!.workingSets));
      }
      for (final e in working) {
        expect(e.sets.length, s.goal!.workingSets);
        expect(s.ex[e.exId]!.rung, before[e.exId]! + 1, reason: 'the proper work counts on an easy day too');
      }
    });

    test('an energy stop with the work done still counts, and the default turns easy after two stops', () {
      final s = fresh();
      run(s, t0, finish: Finish(stopReason: StopReason.energy));
      expect(s.ex['bb_squat']!.rung, 1);
      expect(s.plan!.energyDefault, Energy.normal);
      run(s, t0.add(const Duration(days: 2)), finish: Finish(stopReason: StopReason.energy));
      expect(s.plan!.energyDefault, Energy.easy);
      expect(defaultsFor(s, t0.add(const Duration(days: 3))).energy, Energy.easy);
    });

    test('a time stop makes the minutes you actually had the default', () {
      final s = fresh();
      final a = run(s, t0, minutes: 45, finish: Finish(stopReason: StopReason.time), gapSeconds: 90);
      expect(a.elapsedMinutes, lessThan(45));
      expect(s.plan!.timeDefault, lessThan(45));
      expect(s.plan!.timeDefault % minutesStep, 0);
      expect(defaultsFor(s, t0.add(const Duration(days: 1))).minutes, s.plan!.timeDefault);
    });

    test('calibration: first appearance with an easy feel and every set at the top steps up even with step up = 3', () {
      final s = fresh()..settings.stepUp = 3;
      run(s, t0, finish: Finish(feel: Feel.easy));
      expect(s.ex['bb_squat']!.rung, 1);
    });

    test('bodyweight ladders climb by variant', () {
      final s = fresh(template: 'none');
      final a = run(s, t0);
      final pushup = a.exercises.firstWhere((e) => e.exId == 'pushup');
      expect(pushup.rungLabel, 'Push-ups'); // experience some -> rung 3
      expect(s.ex['pushup']!.rung, 4);
      expect(rungLabel(s, exerciseById['pushup']!, s.ex['pushup']!, 4), 'Feet-elevated push-ups');
    });

    test('at the ceiling the target becomes beating the best total; loading gear opens the ladder', () {
      final s = fresh(template: 'none');
      final ex = exerciseById['pushup']!;
      final st = ensureState(s, ex);
      st.rung = 5; // archer, the top variant without gear
      st.appearances = 1;
      expect(atCeiling(ex, st, const []), isTrue);
      expect(ceilingFor(ex, ['vest']), isNull);
      final a = run(s, t0, repsBy: {'pushup': 12});
      final p = a.exercises.firstWhere((e) => e.exId == 'pushup');
      expect(p.atCeiling, isTrue);
      expect(st.rung, 5);
      expect(st.bestTotal, 12 * p.sets.length);
      final b = run(s, t0.add(const Duration(days: 2)), repsBy: {'pushup': 12}, muscles: chest);
      final p2 = b.exercises.firstWhere((e) => e.exId == 'pushup');
      expect(p2.target, greaterThan(12));
      expect(rungLabel(s, ex, st, 6), 'Archer push-ups +2.5 kg');
    });

    test('three ceiling bests in a row lower the cost in play by one', () {
      final s = fresh(template: 'none');
      final ex = exerciseById['pushup']!;
      final st = ensureState(s, ex)..rung = 5..appearances = 1;
      var reps = 10;
      for (var i = 0; i < 3; i++) {
        run(s, t0.add(Duration(days: 2 * i)), repsBy: {'pushup': reps}, muscles: chest);
        reps += 2;
      }
      expect(difficultyInPlay(ex, st), ex.difficulty - 1);
    });

    test('a saved edit becomes the rung and the decay floor', () {
      final s = fresh();
      final ex = exerciseById['bb_squat']!;
      final st = ensureState(s, ex);
      final rung = rungForLoad(s, ex, st, 60);
      setRung(s, ex, rung);
      expect(loadFor(s, ex, st, st.rung), 60);
      expect(st.startRung, rung);
    });

    test('a loaded exercise seeds from history with another exercise for the same muscle, clamped', () {
      final s = fresh();
      final squat = exerciseById['bb_squat']!;
      final st = ensureState(s, squat)..appearances = 3;
      st.rung = rungForLoad(s, squat, st, 100);
      final goblet = ensureState(s, exerciseById['goblet']!);
      expect(loadFor(s, exerciseById['goblet']!, goblet, 0, middleReps), closeTo(24, stepKg(s, exerciseById['goblet']!))); // twice the library start, the clamp
    });

    test('holds use seconds: the range floors at the ladder range', () {
      final s = fresh(goal: 'strength');
      final r = rangeFor(s, exerciseById['plank']!, lightReps);
      expect(r.lo, 20);
      expect(r.hi, 45);
    });
  });

  group('goal', () {
    test('a custom goal changes rep ranges and the counts without touching rungs', () {
      final s = fresh();
      run(s, t0);
      final rung = s.ex['bb_squat']!.rung;
      s.goal!
        ..bands = strengthBands()
        ..exercises = const Tri(2, 3, 3)
        ..sets = const Tri(2, 4, 4)
        ..moveEvery = 0;
      final sess = build(s, minutes: 60, at: t0.add(const Duration(days: 3)));
      expect(sess.exercises.length, 3);
      expect(sess.exercises.where((e) => e.difficulty == 3).every((e) => e.lo == 4 && e.hi == 7), isTrue);
      expect(sess.exercises.where((e) => e.intent == intentWorking).every((e) => e.sets.length == 4), isTrue);
      expect(s.ex['bb_squat']!.rung, rung);
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
    });
  });

  group('energy and time', () {
    test('hard holds everything normal does; easy keeps a subset at full sets, never more exercises', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 90);
      List<String> ids(Session x) => x.exercises.map((e) => e.exId).toList()..sort();
      for (final m in [25, 35, 60, 90]) {
        final easy = build(s, energy: Energy.easy, minutes: m), normal = build(s, minutes: m), hard = build(s, energy: Energy.hard, minutes: m);
        expect(ids(hard).toSet().containsAll(ids(normal)), isTrue, reason: '$m');
        expect(ids(normal).toSet().containsAll(ids(easy)), isTrue, reason: '$m');
        expect(easy.exercises.length, lessThanOrEqualTo(normal.exercises.length), reason: '$m');
        expect(easy.exercises.every((e) => e.sets.length == s.goal!.workingSets), isTrue, reason: '$m: full sets on easy');
        expect(easy.relative, lessThan(normal.relative), reason: '$m');
        expect(normal.relative, greaterThanOrEqualTo(0.9), reason: '$m'); // a long day grows past the usual
        expect(hard.relative, greaterThanOrEqualTo(normal.relative), reason: '$m');
        expect(sets(easy), lessThanOrEqualTo(sets(normal)), reason: '$m');
        expect(sets(hard), greaterThanOrEqualTo(sets(normal)), reason: '$m');
        expect(normal.exercises.length, lessThanOrEqualTo(s.goal!.exercises.max), reason: '$m');
      }
    });

    test('the exercise calibration: the fewest on a tight day, the ideal usually, the most only on long or hard days', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 60);
      s.goal!.exercises = const Tri(1, 2, 2);
      expect(build(s, minutes: 90).exercises.length, 2);
      s.goal!.exercises = const Tri(2, 4, 8);
      expect(build(s, minutes: 120).exercises.length, greaterThan(4), reason: 'a long day grows to the most');
      expect(build(s, minutes: 120).exercises.length, lessThanOrEqualTo(8));
      expect(build(s, minutes: 120, energy: Energy.easy).exercises.length, lessThanOrEqualTo(4), reason: 'easy never grows past the ideal');
      // a usual day: the ideal list fits and fills more than half the window, so it stays at the ideal
      practiseAll(s, secPerSet: 120);
      final usual = build(s, minutes: 50);
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
      final tighter = build(s, minutes: 15);
      expect(tighter.exercises.length, 2, reason: 'held at the fewest while sets can still shrink');
      expect(tighter.exercises.any((e) => e.sets.length < 3), isTrue);
      expect(tighter.exercises.every((e) => e.sets.isNotEmpty), isTrue);
    });

    test('easy: light everywhere but two at working, chosen among easy and medium exercises', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      final sess = build(s, energy: Energy.easy, minutes: 60);
      final working = sess.exercises.where((e) => e.intent == intentWorking && !e.slot.endsWith('x')).toList();
      expect(working.length, min(2, sess.exercises.where((e) => e.difficulty <= 2 && !e.slot.endsWith('x')).length));
      expect(working.every((e) => e.difficulty <= 2), isTrue, reason: 'hard exercises stay light on an easy day');
      expect(sess.exercises.any((e) => e.intent == intentExtra), isFalse);
      for (final e in sess.exercises.where((e) => e.intent == intentLight)) {
        expect(e.sets.length, s.goal!.workingSets, reason: 'easy keeps full sets and holds fewer exercises');
      }
    });

    test('normal is working everywhere: working sets, the goal expression, aim for the top', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      for (final m in [35, 60, 90]) {
        final sess = build(s, minutes: m);
        expect(sess.exercises.any((e) => e.intent == intentExtra), isFalse, reason: '$m');
        final listed = sess.exercises.where((e) => !e.slot.endsWith('x'));
        expect(listed.every((e) => e.intent == intentWorking && e.sets.length >= s.goal!.sets.ideal && e.sets.length <= s.goal!.sets.max && e.target == e.hi), isTrue, reason: '$m');
        for (final e in listed) { expect(e.range, todayRange(s, e.exercise), reason: e.exId); }
      }
    });

    test('hard: the hardest exercises at the next level on every set, more with the setting, and the gradient holds for the same minutes', () {
      final s = fresh(template: 'gym');
      practiseAll(s, secPerSet: 60);
      final sess = build(s, energy: Energy.hard, minutes: 60);
      final extras = sess.exercises.where((e) => e.intent == intentExtra).toList();
      expect(extras.length, s.goal!.pushes.max, reason: 'a long hard day pushes the most');
      expect(build(s, energy: Energy.hard, minutes: 35).exercises.where((e) => e.intent == intentExtra).length, s.goal!.pushes.ideal, reason: 'a usual hard day pushes the ideal');
      for (final e in extras) {
        expect(e.nextLevel, isTrue);
        expect(e.sets.length, inInclusiveRange(s.goal!.sets.ideal, s.goal!.sets.max));
        expect(e.workingSets, s.goal!.sets.ideal, reason: 'only the usual sets are judged');
        expect(e.rung, s.ex[e.exId]!.rung + 1);
        if (e.exercise.loaded) expect(e.loadKg, greaterThan(e.usualLoadKg!));
      }
      expect(extras.first.difficulty, sess.exercises.map((e) => e.difficulty).reduce(max));
      expect(sess.exercises.first.intent, intentExtra);
      expect(sess.pushes, extras.length);
      s.goal!.pushes = const Tri(1, 1, 1);
      expect(build(s, energy: Energy.hard, minutes: 60).exercises.where((e) => e.intent == intentExtra).length, 1);
      s.goal!.pushes = const Tri(10, 10, 10);
      final all = build(s, energy: Energy.hard, minutes: 90);
      expect(all.exercises.where((e) => e.intent == intentExtra).length, greaterThan(1));
      int listedSets(Session x) => x.exercises.where((e) => !e.slot.endsWith('x')).fold(0, (a, e) => a + e.sets.length);
      int listed(Session x) => x.exercises.where((e) => !e.slot.endsWith('x')).length;
      for (final m in [25, 45, 60, 90]) {
        final e = build(s, energy: Energy.easy, minutes: m), n = build(s, minutes: m), h = build(s, energy: Energy.hard, minutes: m);
        expect(listed(h), greaterThanOrEqualTo(listed(n)), reason: '$m: hard never emptier than normal');
        expect(listedSets(h), greaterThanOrEqualTo(listedSets(n)), reason: '$m');
        expect(listedSets(e), lessThanOrEqualTo(listedSets(n)), reason: '$m');
      }
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

    test('more minutes means more sets, then more exercises, and every size fits its budget', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      int? prevSets;
      int? prevEx;
      for (final m in [15, 25, 35, 45, 60, 75, 90]) {
        final x = build(s, minutes: m);
        expect(estimateMinutes(x), lessThanOrEqualTo(m + 1), reason: '$m min');
        if (prevSets != null) expect(sets(x), greaterThanOrEqualTo(prevSets), reason: '$m min');
        if (prevEx != null) expect(x.exercises.length, greaterThanOrEqualTo(prevEx), reason: '$m min');
        prevSets = sets(x);
        prevEx = x.exercises.length;
      }
      expect(sets(build(s, minutes: 60)), greaterThan(sets(build(s, minutes: 35))));
      expect(build(s, minutes: 90).exercises.length, greaterThan(build(s, minutes: 35).exercises.length));
      expect(sets(build(s, minutes: 15)), lessThan(sets(build(s, minutes: 35))));
    });

    test('emphasised muscles first, then hardest; at the same difficulty extra and working come before light', () {
      final s = fresh(template: 'gym');
      practiseAll(s);
      int tier(String i) => i == intentExtra ? 0 : i == intentWorking ? 1 : 2;
      for (final energy in Energy.values) {
        final sess = build(s, energy: energy, minutes: 60);
        for (var i = 1; i < sess.exercises.length; i++) {
          final a = sess.exercises[i - 1], b = sess.exercises[i];
          expect(b.difficulty, lessThanOrEqualTo(a.difficulty), reason: energy.name);
          if (a.difficulty == b.difficulty) expect(tier(b.intent), greaterThanOrEqualTo(tier(a.intent)), reason: energy.name);
        }
      }
      s.goal!.setEmphasis('calves', 1);
      final sess = build(s, minutes: 60, muscles: const ['calves']);
      expect(sess.exercises.first.muscle, 'calves', reason: 'the muscle the user wants more of leads, whatever its difficulty');
    });

    test('a level is strength: heavier and fewer or lighter and more at the same rung, and every rung moves every expression', () {
      final s = fresh(goal: 'strength', template: 'gym');
      final ex = exerciseById['bb_squat']!;
      final st = ensureState(s, ex);
      final heavy = loadFor(s, ex, st, st.rung, heavyReps), middle = loadFor(s, ex, st, st.rung, middleReps), light = loadFor(s, ex, st, st.rung, lightReps);
      expect(heavy, greaterThan(middle));
      expect(middle, greaterThan(light));
      expect(heavyReps.hi, lessThan(lightReps.lo));
      // the Mixed program alternates heavy and middle by workout on the hard lifts; a card override wins over both
      s.goal!.bands = mixedBands();
      expect(todayRange(s, ex, liftIndex: 0), heavyReps);
      expect(todayRange(s, ex, liftIndex: 1), middleReps);
      expect(todayRange(s, ex, liftIndex: 2), heavyReps);
      st.repsOverride = lightReps;
      expect(todayRange(s, ex, liftIndex: 0), lightReps);
      st.repsOverride = const RepRange(5, 8);
      expect(todayRange(s, ex, liftIndex: 1), const RepRange(5, 8));
      st.repsOverride = null;
      s.goal!.bands = strengthBands();
      for (final band in [heavyReps, middleReps, lightReps, const RepRange(20, 25)]) {
        for (var r = 0; r < 12; r++) {
          expect(loadFor(s, ex, st, r + 1, band), greaterThan(loadFor(s, ex, st, r, band)), reason: '$band rung $r');
        }
      }
      expect(rungForLoad(s, ex, st, loadFor(s, ex, st, 5, lightReps), lightReps), 5);
      // changing the reps the goal likes changes the weight, not the level
      final before = st.rung;
      s.goal!.bands = enduranceBands();
      expect(st.rung, before);
      expect(loadFor(s, ex, st, st.rung), light);
    });

    test('the timing model learns from the gap between set taps', () {
      final s = fresh();
      final before = ensureState(s, exerciseById['bb_squat']!).secPerSet;
      run(s, t0, gapSeconds: 300);
      final after = s.ex['bb_squat']!.secPerSet;
      expect(after, greaterThan(before));
      expect(after, lessThan(300));
      // three days apart, so the quads are strain-free and the squat comes back every time
      for (var i = 0; i < 10; i++) { run(s, t0.add(Duration(days: 3 * (i + 1))), gapSeconds: 300, muscles: quads); }
      expect(s.ex['bb_squat']!.secPerSet, closeTo(300, 5));
    });

    test('a slower lifter gets fewer sets in the same minutes', () {
      final s = fresh(template: 'gym');
      final a = build(s, minutes: 45);
      for (final e in exercises) { ensureState(s, e).secPerSet = 300; }
      final b = build(s, minutes: 45);
      expect(sets(b), lessThan(sets(a)));
    });
  });

  group('decay and breaks', () {
    test('an unused rung decays one per period, never below the start, and re-climbs in one clean session', () {
      final s = fresh();
      run(s, t0);
      final st = s.ex['bb_squat']!;
      expect(st.rung, 1);
      st.rung = 3;
      applyDecay(s, t0.add(const Duration(days: 22)));
      expect(st.rung, 2);
      expect(st.decayedBy, 1);
      expect(st.costUp, 1);
      applyDecay(s, t0.add(const Duration(days: 90)));
      expect(st.rung, 0);
      expect(st.decayedBy, 3);
      s.settings.stepUp = 3;
      final back = run(s, t0.add(const Duration(days: 91)), muscles: quads);
      expect(back.exercises.firstWhere((e) => e.exId == 'bb_squat').lightened, isTrue, reason: 'first workout back: cost-5 lifts one level down, neutral');
      expect(st.rung, 0);
      run(s, t0.add(const Duration(days: 94)), muscles: quads);   // once the quads are strain-free again
      expect(st.rung, 1, reason: 'the first clean workout at the working level steps straight back up');
      expect(st.costUp, 0);
    });

    test('decay can be switched off', () {
      final s = fresh()..settings.decayWeeks = 0;
      run(s, t0);
      final st = s.ex['bb_squat']!..rung = 3;
      applyDecay(s, t0.add(const Duration(days: 200)));
      expect(st.rung, 3);
    });

    test('after a week away the default is easy and cost-5 lifts start one rung down', () {
      final s = fresh();
      run(s, t0);
      final later = t0.add(const Duration(days: 8));
      expect(personState(s, later).state, PersonState.away);
      expect(defaultsFor(s, later).energy, Energy.easy);
      s.ex['bb_squat']!.rung = 3;
      final sess = build(s, at: later, muscles: quads);
      final squat = sess.exercises.firstWhere((e) => e.exId == 'bb_squat');
      expect(squat.lightened, isTrue);
      expect(squat.rung, 2);
    });

    test('person state: active, at risk after 3 days, away after the setting', () {
      final s = fresh();
      run(s, t0);
      expect(personState(s, t0.add(const Duration(days: 1))).state, PersonState.active);
      expect(personState(s, t0.add(const Duration(days: 3))).state, PersonState.atRisk);
      expect(personState(s, t0.add(const Duration(days: 7))).state, PersonState.away);
      expect(nudgeFor(s, t0.add(const Duration(days: 3))), isNotNull);
      s.person.nudgeDismissed = true;
      expect(nudgeFor(s, t0.add(const Duration(days: 4))), isNull);
    });

    test('pain pauses the exercise and its muscles, and brings it back one rung down', () {
      final s = fresh(template: 'gym');
      run(s, t0);
      final b = build(s, at: t0.add(const Duration(days: 2)), muscles: quads);
      startSession(s, b, t0.add(const Duration(days: 2)));
      logSet(b, 0, 12, t0.add(const Duration(days: 2, minutes: 2)));
      final sq = b.exercises.indexWhere((e) => e.exId == 'bb_squat');
      expect(sq, greaterThanOrEqualTo(0));
      finishSession(s, b, Finish(stopReason: StopReason.pain, stopAt: sq), t0.add(const Duration(days: 2, minutes: 10)));
      expect(s.plan!.paused.containsKey('bb_squat'), isTrue);
      final c = build(s, at: t0.add(const Duration(days: 4)), muscles: quads);
      expect(c.exercises.any((e) => e.exId == 'bb_squat'), isFalse);
      expect(c.exercises.any((e) => e.exercise.primary.contains('quads')), isFalse, reason: 'the muscles rest too');
      final rungBefore = s.ex['bb_squat']!.rung;
      final d = build(s, at: t0.add(const Duration(days: 10)), muscles: quads);
      expect(d.exercises.any((e) => e.exId == 'bb_squat'), isTrue);
      expect(s.ex['bb_squat']!.rung, max(floorRung(s, exerciseById['bb_squat']!, s.ex['bb_squat']!), rungBefore - 1));
    });
  });

  group('plumbing', () {
    test('state survives a JSON round trip', () {
      final s = fresh(template: 'gym');
      run(s, t0, finish: Finish(feel: Feel.right));
      final json = jsonEncode(s.toJson());
      final back = AppState.fromJson(jsonDecode(json));
      expect(jsonEncode(back.toJson()), json);
      expect(back.sessions.length, 1);
      expect(back.goal!.name, s.goal!.name);
      expect(back.ex['bb_squat']!.rung, s.ex['bb_squat']!.rung);
    });

    test('movement sessions take the minutes given, and a movement day comes due after the goal\'s count of lifts', () {
      final s = fresh(goal: 'fit');   // a movement day after every two lifting days
      expect(moveDue(s), isNull);
      final m = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 25, moveKind: 'cardio'), t0);
      expect(m.type, 'move');
      expect(m.minutes, 25);
      startSession(s, m, t0);
      finishSession(s, m, Finish(effort: 2), t0.add(const Duration(minutes: 26)));
      run(s, t0.add(const Duration(days: 1)));
      expect(moveDue(s), isNull);
      run(s, t0.add(const Duration(days: 2)));
      expect(moveDue(s), 'mobility', reason: 'cardio and mobility take turns');
      expect(buildSession(s, BuildOptions(energy: Energy.normal, minutes: 25), t0.add(const Duration(days: 3))).type, 'move');
      expect(buildSession(s, BuildOptions(energy: Energy.normal, minutes: 25, liftInstead: true), t0.add(const Duration(days: 3))).type, 'lift');
    });

    test('swaps keep rungs on the exercise and shuffles stay within the muscle', () {
      final s = fresh(template: 'gym');
      final sess = build(s);
      final alts = alternatives(s, sess, 0, s.locations.first.equipment, t0);
      expect(alts.every((e) => e.primary.contains(sess.exercises[0].muscle)), isTrue);
      final picks = shufflePicks(s, sess, s.locations.first.equipment, Random(1), t0);
      for (final e in sess.exercises) { expect(exerciseById[picks[e.slot]]!.primary, contains(e.muscle)); }
    });

    test('pounds change the step and the label but not the stored kilograms', () {
      final s = fresh()..units = 'lb';
      final ex = exerciseById['bb_squat']!;
      final st = ensureState(s, ex);
      expect(stepKg(s, ex), closeTo(5 / lbPerKg, 0.001));
      expect(rungLabel(s, ex, st, 0), endsWith('lb'));
    });
  });

  group('your data', () {
    test('a copy restores into another install, and anything else changes nothing', () {
      final s = fresh();
      run(s, t0);
      final from = Store(s, null);
      final to = Store(AppState(), null);
      expect(Store.looksLikeData(from.exportJson()), isTrue);
      expect(to.importJson(from.exportJson()), isTrue);
      final copied = jsonEncode(to.state.toJson());
      expect(copied, jsonEncode(s.toJson()));
      for (final junk in ['', 'hello', '{}', '[]', '{"profile": 1, "plan": 2}', jsonEncode(AppState().toJson())]) {
        expect(Store.looksLikeData(junk), isFalse, reason: junk);
        expect(to.importJson(junk), isFalse, reason: junk);
      }
      expect(jsonEncode(to.state.toJson()), copied);
    });
  });
}
