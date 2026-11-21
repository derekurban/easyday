import 'dart:convert';

import 'package:easyday/data/model.dart';
import 'package:easyday/data/store.dart';
import 'package:easyday/logic/calibrate.dart';
import 'package:easyday/logic/heart.dart';
import 'package:easyday/logic/watch_view.dart';
import 'package:easyday/logic/workout.dart';
import 'package:easyday/ui/app.dart';
import 'package:easyday/ui/session.dart';
import 'package:easyday/ui/theme.dart';
import 'package:easyday/watch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test.dart' as w;

/// The watch: what the phone sends it, which taps from it still apply, and the heart rate it records.
void main() {
  group('the view', () {
    test('a set, then the rest after it, then the next set; each step its own token', () {
      final s = w.fresh(template: 'gym');
      final x = w.build(s, warmup: 0);
      startWorkout(s, x, w.t0);
      final e = x.exercises[0];

      var v = watchView(s, w.at(10));
      expect(v['phase'], 'lift');
      expect(v['record'], isTrue);
      expect(v['ex']['name'], e.exercise.name);
      expect(v['ex']['set'], 1);
      expect(v['ex']['sets'], e.sets.length);
      final values = v['ex']['values'] as List<int>;
      expect(values[v['ex']['initial'] as int], e.hi, reason: 'opens on the top of the range');
      final lift = watchStep(s);

      logReps(s, x, e.hi - 2, w.at(40));
      v = watchView(s, w.at(41));
      expect(v['phase'], 'rest');
      expect(v['rest']['last'], '${e.hi - 2} ${e.exercise.repLabel == 'seconds' ? 'seconds' : 'reps'}');
      expect(v['rest']['button'], 'Start set 2');
      expect(watchStep(s), isNot(lift));

      ready(x, w.at(120));
      v = watchView(s, w.at(121));
      expect(v['phase'], 'lift');
      expect(v['ex']['set'], 2);
      expect((v['ex']['values'] as List<int>)[v['ex']['initial'] as int], e.hi - 2, reason: 'the wheel opens on the last set');
      expect(v['steps']['done'], 1);
    });

    test('paused: the clock stops on the watch too; ended: the finish is on the phone and nothing records', () {
      final s = w.fresh();
      final x = w.build(s, warmup: 0);
      startWorkout(s, x, w.t0);
      pauseWorkout(x, w.at(30));
      expect(watchView(s, w.at(31))['pausedAt'], w.at(30).millisecondsSinceEpoch);
      resumeWorkout(x, w.at(90));
      expect(watchView(s, w.at(91)).containsKey('pausedAt'), isFalse);
      x.endedAt = w.at(200);
      x.reviewing = true;
      final v = watchView(s, w.at(201));
      expect(v['phase'], 'review');
      expect(v['record'], isFalse);
    });

    test('no workout: Today, when it is up, or a line', () {
      final s = w.fresh();
      expect(watchView(s, w.t0)['phase'], 'idle');
      final today = WatchToday(name: 'Lats and biceps day', detail: '5 exercises · about 40 min', start: () {});
      final v = watchView(s, w.t0, today: today);
      expect(v['phase'], 'today');
      expect(v['plan']['canStart'], isTrue);
      expect(v['step'], 'today Lats and biceps day');
      expect(() => jsonEncode(v), returnsNormally);
    });

    test('a circuit rests between rounds and names the next exercise', () {
      final s = w.fresh(template: 'gym');
      final x = w.build(s, warmup: 0, circuit: true);
      startWorkout(s, x, w.t0);
      logReps(s, x, x.exercises[0].hi, w.at(30));
      final v = watchView(s, w.at(31));
      expect(v['phase'], 'rest');
      expect(v['rest']['next'], shortExerciseName(x.exercises[1].exercise.name));
    });

    test('free form lists what is left and how to move on', () {
      final s = w.fresh(template: 'gym');
      final x = w.build(s, warmup: 0, order: WorkoutOrder.free);
      startWorkout(s, x, w.t0);
      final v = watchView(s, w.at(5));
      expect(v['phase'], 'choose');
      expect((v['choices'] as List).length, x.exercises.length);
      expect(v['choices'][0]['detail'], startsWith('Set 1 of'));
    });
  });

  group('taps', () {
    test('only a tap on the step under way moves it on; pause and end need only the workout', () {
      final s = w.fresh();
      final x = w.build(s, warmup: 0);
      startWorkout(s, x, w.t0);
      final now = w.at(30);
      final step = watchStep(s);
      Map<String, dynamic> cmd(String op, {String? on, int? at}) =>
          {'op': op, 'step': on ?? step, 'session': x.id, 'at': (at ?? now.millisecondsSinceEpoch)};
      expect(watchCommandApplies(s, cmd('log'), now), isTrue);
      expect(watchCommandApplies(s, cmd('log', on: 'old step'), now), isFalse);
      expect(watchCommandApplies(s, cmd('pause', on: 'old step'), now), isTrue);
      expect(watchCommandApplies(s, cmd('log', at: w.at(-600).millisecondsSinceEpoch), now), isFalse, reason: 'too old');
      expect(watchCommandApplies(s, {...cmd('end'), 'session': 'another'}, now), isFalse);
      expect(watchCommandApplies(s, cmd('format'), now), isFalse);
      expect(watchCommandApplies(s, cmd('start'), now), isFalse, reason: 'a workout is under way');
    });

    test('Start applies only while Today can start one', () {
      final s = w.fresh();
      final today = WatchToday(name: 'Push day', detail: '', start: () {});
      final cmd = {'op': 'start', 'step': watchStep(s, today: today), 'at': w.t0.millisecondsSinceEpoch};
      expect(watchCommandApplies(s, cmd, w.t0, today: today), isTrue);
      expect(watchCommandApplies(s, cmd, w.t0), isFalse);
      expect(watchCommandApplies(s, cmd, w.t0, today: const WatchToday(name: 'Push day', detail: '')), isFalse);
    });
  });

  group('heart', () {
    test('kept in order, one per five seconds, plausible readings only; a batch sent twice changes nothing', () {
      final x = Session(id: 's1', type: 'lift', name: 'x', locationId: null, energy: Energy.normal, timeMinutes: 30, energyChosen: false, timeChosen: false, stateAtStart: PersonState.active);
      final batch = [for (var i = 0; i < 20; i++) (w.at(i), 100 + i)];
      addHeart(x, batch, kcal: 12, device: 'Galaxy Watch4');
      addHeart(x, batch, kcal: 10);
      addHeart(x, [(w.at(21), 250), (w.at(30), 20)]);
      expect(x.heart!.t, [w.at(0), w.at(5), w.at(10), w.at(15)]);
      expect(x.heart!.bpm, [100, 105, 110, 115]);
      expect(x.heart!.kcal, 12, reason: 'a running total: the larger stands');
      expect(x.heart!.device, 'Galaxy Watch4');
      // out of order, later
      addHeart(x, [(w.at(40), 130), (w.at(25), 120)]);
      expect(x.heart!.bpm, [100, 105, 110, 115, 120, 130]);
    });

    test('laid on the workout clock: a pause moves what came before it on, and what came in it is dropped', () {
      final s = w.fresh();
      final x = w.build(s, warmup: 0);
      startWorkout(s, x, w.t0);
      pauseWorkout(x, w.at(60));
      resumeWorkout(x, w.at(120));
      expect(x.startedAt, w.at(60), reason: 'resuming moved the start on by the minute paused');
      expect(onWorkoutClock(x, w.at(30)), w.at(90));
      expect(onWorkoutClock(x, w.at(90)), isNull);
      expect(onWorkoutClock(x, w.at(130)), w.at(130));
      addHeart(x, [for (var i = 0; i < 200; i += 5) (w.at(i), 90 + i ~/ 5)]);
      x.endedAt = w.at(200);
      final pts = heartPoints(x);
      expect(pts.every((p) => !p.t.isBefore(x.startedAt!) && !p.t.isAfter(x.endedAt!)), isTrue);
      expect(pts.length, 40 - 12, reason: 'the twelve samples inside the pause are gone');
      final h = heartSummary(x)!;
      expect(h.peak, pts.map((p) => p.bpm).reduce((a, b) => a > b ? a : b));
      expect(heartLine(h), startsWith('Heart ${h.avg} avg · ${h.peak} peak'));
    });

    test('a set peaks from its start to a little after its reps, not into the next set', () {
      final s = w.fresh();
      final x = w.build(s, warmup: 0);
      startWorkout(s, x, w.t0);              // set 1 from 0
      logReps(s, x, 8, w.at(40));            // to 40
      ready(x, w.at(50));                    // set 2 from 50
      logReps(s, x, 8, w.at(90));
      addHeart(x, [(w.at(0), 90), (w.at(35), 120), (w.at(45), 150), (w.at(55), 170), (w.at(85), 140)]);
      x.endedAt = w.at(100);
      expect(setPeak(x, (ex: 0, set: 0)), 150, reason: 'the climb after the reps counts, the next set does not');
      expect(setPeak(x, (ex: 0, set: 1)), 170);
      expect(exercisePeak(x, 0), 170);
    });

    test('kept with the workout and read back', () {
      final s = w.fresh();
      final x = w.build(s, warmup: 0);
      startWorkout(s, x, w.t0);
      pauseWorkout(x, w.at(10));
      resumeWorkout(x, w.at(20));
      addHeart(x, [(w.at(30), 120), (w.at(36), 125)], kcal: 4.5, device: 'Watch');
      final back = Session.fromJson(jsonDecode(jsonEncode(x.toJson())) as Map<String, dynamic>);
      expect(back.heart!.t, x.heart!.t);
      expect(back.heart!.bpm, [120, 125]);
      expect(back.heart!.kcal, 4.5);
      expect(back.pauses.single.at, w.at(10));
      expect(back.pauses.single.ms, 10000);
    });
  });

  testWidgets('a tap from the watch does what the button on the phone does', (tester) async {
    tester.view.physicalSize = const Size(412, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = w.fresh(template: 'gym');
    final x = w.build(s, warmup: 0);
    startWorkout(s, x, DateTime.now().subtract(const Duration(seconds: 40)));
    s.active = x;
    await tester.pumpWidget(StoreScope(store: Store(s, null), child: MaterialApp(theme: buildTheme(Brightness.dark), home: const SessionScreen())));
    await tester.pump(const Duration(seconds: 1));
    expect(WatchLink.onCommand, isNotNull);
    expect(WatchLink.onCommand!({'op': 'log', 'reps': 7}), isTrue);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(x.exercises[0].sets[0].reps, 7);
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Start set 2'), findsWidgets);
    expect(WatchLink.onCommand!({'op': 'log', 'reps': 7}), isFalse, reason: 'resting: there is no set to log');
    expect(WatchLink.onCommand!({'op': 'ready'}), isTrue);
    await tester.pump(const Duration(seconds: 4));
    expect(liftingSet(x, currentItem(x)!), (ex: 0, set: 1));
    expect(WatchLink.onCommand!({'op': 'pause'}), isTrue);
    expect(x.pausedAt, isNotNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    expect(WatchLink.onCommand, isNull, reason: 'gone with the screen');
  });
}
