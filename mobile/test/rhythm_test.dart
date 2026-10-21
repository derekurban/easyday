import 'dart:convert';

import 'package:easyday/data/index.dart';
import 'package:easyday/data/library.dart';
import 'package:easyday/data/model.dart';
import 'package:easyday/logic/after.dart';
import 'package:easyday/logic/builder.dart';
import 'package:easyday/logic/forecast.dart';
import 'package:easyday/logic/ladder.dart';
import 'package:easyday/logic/muscle_map.dart';
import 'package:easyday/logic/muscle_plan.dart';
import 'package:easyday/logic/selection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'muscle_plan_test.dart' as fixture;

final now = fixture.t0;
AppState fresh() => fixture.fresh(template: 'gym');
Set<String> worked(Session x) => workedInOrder(x.exercises).toSet();
List<String> ids(Session x) => x.exercises.map((e) => e.exId).toList();

void finish(AppState s, Session x, DateTime at) {
  startSession(s, x, at);
  var clock = at;
  for (var i = 0; i < x.exercises.length; i++) {
    for (final _ in x.exercises[i].sets) {
      clock = clock.add(const Duration(minutes: 2));
      logSet(x, i, x.exercises[i].target, clock);
    }
  }
  finishSession(s, x, Finish(), clock);
}

BuildOptions options({int? muscleSeed, int? exerciseSeed, List<String> muscles = const [],
    bool manual = false, int count = 4, Map<String, String> picks = const {},
    Set<String> excluded = const {}, Set<String> leftOut = const {}, List<String>? requirements}) =>
  BuildOptions(energy: Energy.normal, minutes: 60, exerciseCount: count, muscles: muscles,
    manual: manual, muscleSeed: muscleSeed, exerciseSeed: exerciseSeed, picks: picks,
    excluded: excluded, leftOut: leftOut, requirements: requirements, liftInstead: true);

void main() {
  group('rhythm', () {
    test('helper work resets the passive clock but never the direct clock', () {
      final s = fresh();
      final x = buildSession(s, options(muscles: ['chest'], manual: true,
        picks: {'chest1': 'bb_bench'}), now);
      final helpers = x.exercises.single.exercise.secondary;
      expect(helpers, contains('triceps'));
      finish(s, x, now);
      final r = rhythmOver(s, now.add(const Duration(days: 3)));
      expect(r.sinceOf('chest'), 0);
      expect(r.neverWorked('triceps'), isTrue);
      expect(r.helpedSinceOf('triceps'), 0);
      expect(r.overdue('triceps'), greaterThan(r.overdue('chest')));
      expect(MuscleMap(s).currentStrainPoints(now.add(const Duration(hours: 2)))['triceps'], greaterThan(0));
    });

    test('frequency scales direct recency and persists independently of the tag', () {
      final s = fresh();
      s.goal!.setOften('chest', 1);
      s.goal!.setOften('biceps', -1);
      final r = rhythmOver(s, now);
      expect(r.overdue('chest'), 2);
      expect(r.overdue('biceps'), 0.5);
      s.goal!.setTag('chest', MuscleTag.passive);
      final restored = AppState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(restored.goal!.tagOf('chest'), MuscleTag.passive);
      expect(restored.goal!.oftenOf('chest'), 1);
    });

    test('passive and ignored muscles get no places, but either can be forced today', () {
      final s = fresh();
      for (final m in trackedMuscles) { s.goal!.setTag(m, MuscleTag.ignored); }
      s.goal!.setTag('triceps', MuscleTag.passive);
      expect(buildSession(s, options(), now).exercises, isEmpty);
      for (final m in ['triceps', 'calves']) {
        expect(worked(buildSession(s, options(muscles: [m], manual: true), now)), contains(m));
      }
      expect(s.goal!.tagOf('calves'), MuscleTag.ignored);
    });

    test('defaults exclude ignored muscles and strained muscles', () {
      final s = fresh();
      final states = defaultMuscleStates(StrainPoints.none, s.goal);
      expect(states['shins'], MuscleState.excluded);
      expect(states['chest'], MuscleState.available);
      expect(states['forearms'], MuscleState.available);
    });

    test('pauses remain constraints even for forced muscles and pinned exercises', () {
      final s = fresh();
      s.plan!.paused['bb_bench'] = now.add(const Duration(days: 3));
      final x = buildSession(s, options(muscles: ['chest'], manual: true,
        picks: {'chest1': 'bb_bench'}), now);
      expect(worked(x), isNot(contains('chest')));
      expect(x.uncovered, contains('chest'));
    });
  });

  group('draws and swaps', () {
    test('fitting an automatic workout is not an uncovered promise', () {
      final s = fresh();
      final x = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 25, warmupMinutes: 5), now);
      expect(x.exercises.length, lessThan(s.goal!.exercises.ideal));
      expect(x.uncovered, isEmpty);
      expect(worked(x), containsAll(x.requirements));
    });

    test('exercise draws retain automatic requirements across many seeds', () {
      for (final template in ['gym', 'home_full', 'none']) {
        final s = fixture.fresh(template: template);
        final base = buildSession(s, options(), now);
        final must = base.requirements.where((m) => !base.uncovered.contains(m)).toSet();
        for (var seed = 1; seed <= 30; seed++) {
          final x = buildSession(s, options(exerciseSeed: seed), now);
          // If a cover cannot fit, the exact missing requirements must be visible.
          expect({...worked(x), ...x.uncovered}, containsAll(must), reason: '$template seed $seed');
          expect(x.requirements.toSet(), base.requirements.toSet());
          expect(ids(buildSession(s, options(exerciseSeed: seed), now)), ids(x));
        }
        final next = nextExerciseSeed(s, options(), now);
        expect(worked(buildSession(s, options(exerciseSeed: next == 0 ? null : next), now)), containsAll(must));
      }
    });

    test('a multi-primary requirement stays covered under exercise shuffles', () {
      final s = fresh();
      final variants = <String>{};
      for (var seed = 1; seed <= 30; seed++) {
        final x = buildSession(s, options(muscles: ['quads', 'glutes'], manual: true, count: 1, exerciseSeed: seed), now);
        expect(x.exercises, hasLength(1));
        expect(worked(x), containsAll(['quads', 'glutes']));
        expect(x.uncovered, isEmpty);
        variants.add(x.exercises.single.exId);
      }
      expect(variants.length, greaterThan(1));
    });

    test('a manual swap is repaired when there is room, or visibly uncovered', () {
      final s = fresh();
      final legExtension = exercises.firstWhere((e) => e.isStrength && e.primary.contains('quads') &&
        !e.primary.contains('glutes') && available(e, s.locations.first.equipment));
      for (final count in [1, 2]) {
        final x = buildSession(s, options(muscles: ['quads', 'glutes'], manual: true, count: count,
          picks: {'quads1': legExtension.id}), now);
        expect(ids(x), contains(legExtension.id));
        if (count == 2) {
          expect(worked(x), contains('glutes'));
          expect(x.uncovered, isEmpty);
        } else {
          expect(x.uncovered, contains('glutes'));
        }
      }
    });

    test('muscle and exercise shuffles preserve pins, exclusions and skipped places', () {
      final s = fresh();
      for (var seed = 1; seed <= 12; seed++) {
        final x = buildSession(s, options(muscleSeed: seed, exerciseSeed: seed,
          picks: {'chest1': 'bb_bench'}, excluded: {'calves'}, leftOut: {'quads1'}), now);
        expect(ids(x), contains('bb_bench'));
        expect(worked(x), isNot(contains('calves')));
        expect(x.exercises.map((e) => e.slot), isNot(contains('quads1')));
      }
    });

    test('Back restores both seeds and requirements; Reset restores the initial draw', () {
      final s = fresh();
      final p = MusclePlan();
      final base = buildSession(s, options(), now);
      p.draw(exercises: 3, keep: base.requirements);
      final a = buildSession(s, options(exerciseSeed: p.exerciseDraw, requirements: p.requirements), now);
      p.draw(muscles: 7);
      expect(p.requirements, isNull);
      p.back();
      expect(p.lastDraw, 'exercises');
      expect(ids(buildSession(s, options(exerciseSeed: p.exerciseDraw, requirements: p.requirements), now)), ids(a));
      p.resetDraws();
      expect(p.drawn, isFalse);
      expect(p.canGoBack, isFalse);
      expect(ids(buildSession(s, options(), now)), ids(base));
    });

    test('alternatives are ordered by the rules with reasons and no shuffle seed', () {
      final s = fresh();
      final x = buildSession(s, options(muscles: ['quads', 'glutes'], manual: true), now);
      final a = alternativesFor(s, x, 0, s.locations.first.equipment, now);
      expect(a, isNotEmpty);
      expect(a.first.exercise.primary, contains('glutes'));
      expect(a.first.reason, contains('also covers glutes'));
      final disliked = a.first.exercise;
      ensureState(s, disliked).preference = prefNo;
      final ranked = alternativesFor(s, x, 0, s.locations.first.equipment, now);
      expect(ranked.last.exercise.id, disliked.id);
    });
  });

  group('forecast', () {
    test('dry runs are deterministic and never mutate real state', () {
      final s = fresh();
      final before = jsonEncode(s.toJson());
      final f = forecast(s, now);
      expect(jsonEncode(s.toJson()), before);
      expect(f.names, forecast(s, now).names);
      expect(f.names, hasLength(12));
      for (final m in s.goal!.activeMuscles) {
        expect(f.directOf(m), greaterThan(0), reason: m);
      }
      expect(f.helpedByText('shins'), contains('next 12'));
    });

    test('passive evidence includes incidental primary work as well as helpers', () {
      final s = fresh();
      for (final m in trackedMuscles) { s.goal!.setTag(m, MuscleTag.passive); }
      s.goal!.setTag('quads', MuscleTag.active);
      s.settings.timeLimit = false;
      s.goal!.exercises = const Tri(1, 1, 1);
      final f = forecast(s, now);
      expect(f.helpedOf('glutes'), greaterThan(0));
      expect(f.helpedBy['glutes'], isNotEmpty);
    });

    test('more often gets more direct turns and passive calves report no help', () {
      final s = fresh();
      s.goal!.setOften('chest', 1);
      s.goal!.setOften('biceps', -1);
      s.goal!.setTag('calves', MuscleTag.passive);
      final f = forecast(s, now, workouts: 36);
      expect(f.directOf('chest'), greaterThan(f.directOf('biceps')));
      expect(f.helpedOf('calves'), 0);
      expect(f.helpedByText('calves'), contains('no help'));
    });
  });
}
