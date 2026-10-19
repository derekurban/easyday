import 'package:fitness/data/library.dart';
import 'package:fitness/data/model.dart';
import 'package:fitness/logic/after.dart';
import 'package:fitness/logic/builder.dart';
import 'package:fitness/logic/rotation.dart';
import 'package:fitness/logic/workout.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 10, 18, 9);

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

Session build(AppState s, {int minutes = 45, int warmup = 5, bool circuit = false, int? count}) =>
    buildSession(s, BuildOptions(energy: Energy.normal, minutes: minutes, warmupMinutes: warmup, circuit: circuit, exerciseCount: count), t0);

DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

void main() {
  group('items', () {
    test('warm-up, each exercise, cardio and stretching, in that order; a circuit is one item', () {
      final s = fresh();
      final x = build(s);
      final keys = workoutItems(x).map((i) => i.key).toList();
      expect(keys.first, 'warmup');
      expect(keys.where((k) => k.startsWith('ex')).length, x.exercises.length);
      if (x.cardioMinutes > 0) expect(keys, contains('cardio'));
      if (x.stretchMinutes > 0) expect(keys.last, 'stretch');
      final c = build(s, circuit: true);
      expect(workoutItems(c).where((i) => i.kind == ItemKind.circuit).length, 1);
      expect(workoutItems(c).where((i) => i.kind == ItemKind.exercise), isEmpty);
    });

    test('a circuit goes round by round', () {
      final s = fresh();
      final c = build(s, circuit: true);
      final order = setOrder(c, workoutItems(c).firstWhere((i) => i.lifting));
      final n = c.exercises.length;
      expect(order.take(n).map((r) => r.ex).toList(), [for (var i = 0; i < n; i++) i]);
      expect(order.take(n).every((r) => r.set == 0), isTrue);
      expect(order[n].set, 1);
    });
  });

  group('reps then I am ready', () {
    test('start lifts at once; reps end the set; I am ready starts the next; the last set leads to the next item', () {
      final s = fresh();
      final x = build(s, warmup: 0);
      startWorkout(s, x, t0);
      final first = currentItem(x)!;
      expect(first.key, 'ex0');
      expect(liftingSet(x, first), isNotNull, reason: 'Start means ready to go');
      enterReps(x, x.exercises[0].hi, at(30));
      expect(liftingSet(x, first), isNull);
      expect(x.exercises[0].sets[0].reps, x.exercises[0].hi);
      expect(plannedRest(x, first), restFor(x.exercises[0].range));
      expect(ready(x, at(150)), isTrue);
      expect(x.exercises[0].sets[1].start, at(150));
      // the rest of the sets
      var clock = 150;
      for (var k = 1; k < x.exercises[0].sets.length; k++) {
        clock += 30; enterReps(x, x.exercises[0].hi, at(clock));
        if (k < x.exercises[0].sets.length - 1) { clock += 120; ready(x, at(clock)); }
      }
      expect(plannedRest(x, first), isNull, reason: 'nothing left of this exercise');
      clock += 200;
      expect(ready(x, at(clock)), isTrue);
      expect(currentItem(x)!.key, 'ex1');
      expect(liftingSet(x, currentItem(x)!), isNotNull);
    });

    test('reps with nothing under way correct the last set; they never start one', () {
      final s = fresh();
      final x = build(s, warmup: 0);
      startWorkout(s, x, t0);
      enterReps(x, 5, at(30));
      enterReps(x, 7, at(60));
      expect(x.exercises[0].sets[0].reps, 7);
      expect(x.exercises[0].sets[0].at, at(30), reason: 'a correction keeps the time');
      expect(x.exercises[0].sets[1].attempted, isFalse);
    });

    test('lifting is I am ready to the reps; rest is the rest of the item, setting up included', () {
      final s = fresh();
      final x = build(s, warmup: 0);
      startWorkout(s, x, t0);
      enterReps(x, 8, at(40));          // 40 s lifting
      ready(x, at(160));                // 120 s rest
      enterReps(x, 8, at(200));         // 40 s lifting
      final item = currentItem(x)!;
      final split = itemSplit(x, item, at(260)); // 60 s resting so far
      expect(split.lifting, closeTo(80, 0.01));
      expect(split.rest, closeTo(180, 0.01));
    });

    test('a circuit rests between rounds and moves between exercises without a timer', () {
      final s = fresh();
      final x = build(s, warmup: 0, circuit: true);
      startWorkout(s, x, t0);
      final item = currentItem(x)!;
      final n = x.exercises.length;
      var clock = 0;
      for (var k = 0; k < n; k++) {
        clock += 30; enterReps(x, x.exercises[k].hi, at(clock));
        if (k < n - 1) {
          expect(plannedRest(x, item), isNull, reason: 'next is a different exercise');
          clock += 40; ready(x, at(clock));
        }
      }
      expect(plannedRest(x, item), roundRestSeconds);
      expect(restDue(x, item), at(clock + roundRestSeconds));
    });

    test('moving on with an exercise untouched skips it, so it is not judged', () {
      final s = fresh();
      final x = build(s, warmup: 0);
      startWorkout(s, x, t0);
      jumpTo(x, 'ex2', at(10));
      expect(x.skipped, containsAll([0, 1]));
      expect(currentItem(x)!.key, 'ex2');
      expect(x.exercises[0].sets.every((e) => e.start == null), isTrue, reason: 'the dropped set loses its start');
    });

    test('after the last item there is nothing left to be ready for', () {
      final s = fresh();
      final x = build(s, warmup: 0)..cardioMinutes = 0..stretchMinutes = 0;
      startWorkout(s, x, t0);
      final items = workoutItems(x);
      jumpTo(x, items.last.key, at(5));
      for (final r in setOrder(x, items.last)) { enterReps(x, 8, at(10)); ready(x, at(20)); expect(r, isNotNull); }
      expect(ready(x, at(30)), isFalse);
    });
  });

  group('the timing model', () {
    test('an exercise learns its seconds per set from its whole time on the strip', () {
      final s = fresh();
      final x = build(s, warmup: 0)..cardioMinutes = 0..stretchMinutes = 0;
      final e = x.exercises[0];
      startWorkout(s, x, t0);
      final before = s.ex[e.exId]!.secPerSet;
      // every set 30 s lifting and 270 s rest: 300 s a set, much slower than the seed
      var clock = 0;
      for (var k = 0; k < e.sets.length; k++) { clock += 30; enterReps(x, e.hi, at(clock)); clock += 270; ready(x, at(clock)); }
      finishSession(s, x, Finish(stopReason: StopReason.none), at(clock + 10));
      final expected = ((clock - changeSeconds - (e.warmups.isNotEmpty ? warmupSetsSeconds : 0)) / e.sets.length).clamp(20.0, 600.0);
      expect(s.ex[e.exId]!.secPerSet, closeTo(before * 0.7 + expected * 0.3, 0.5));
    });
  });

  group('no time limit', () {
    test('the count decides how many exercises, and the minutes follow', () {
      final s = fresh(template: 'gym');
      for (final n in [2, 3, 5]) {
        final x = build(s, count: n);
        expect(x.exercises.length, n, reason: '$n');
        expect(x.spareMinutes, 0);
      }
      expect(estimateMinutes(build(s, count: 5)), greaterThan(estimateMinutes(build(s, count: 2))));
    });

    test('the warm-up is inside the minutes', () {
      final s = fresh(template: 'gym');
      final a = build(s, minutes: 45, warmup: 0), b = build(s, minutes: 45, warmup: 8);
      expect(b.warmupMinutes, 8);
      expect(estimateMinutes(b) + b.spareMinutes, lessThanOrEqualTo(46));
      int sets(Session x) => x.exercises.fold(0, (t, e) => t + e.sets.length);
      expect(sets(b), lessThanOrEqualTo(sets(a)));
    });
  });
}
