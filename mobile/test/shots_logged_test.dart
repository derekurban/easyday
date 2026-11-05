// Renders the end of a lifting workout: the finish screen in the kinds of day it reads (a first time, stronger than
// last time, a low-energy day, an early end it has to ask about), the details behind it, and the edit drawers, light
// and dark, to PNG files. Not part of the suite:
//   flutter test --run-skipped test/shots_logged_test.dart   (SHOTS_DIR sets the folder, build/shots by default)
@Skip('Screenshots of the finish for review, not a check.')
library;

import 'package:easyday/data/model.dart';
import 'package:easyday/data/store.dart';
import 'package:easyday/logic/after.dart';
import 'package:easyday/logic/calibrate.dart';
import 'package:easyday/logic/ladder.dart';
import 'package:easyday/logic/score.dart';
import 'package:easyday/logic/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shots_test.dart' show loadFonts, snap, settle;
import 'workout_test.dart' as w;

/// Play a workout through the workout logic: every set takes [lift] seconds, then [rest] before the next. [reps] gives
/// each exercise's reps by set; an exercise with none is never started. Ends [endAfter] minutes in when given. With
/// [before], a first workout is played and logged two days earlier, so this one can be read against it.
Store play(List<List<int>> Function(Session x) reps, {bool first = false, bool calibrating = false, int lift = 35, int rest = 90, int? endAfter, int minutes = 45, int warmup = 0,
    List<List<int>> Function(Session x)? before}) {
  final s = w.fresh(template: 'gym');
  Session run(List<List<int>> Function(Session x) plan, DateTime at, int? end) {
    final x = w.build(s, warmup: warmup, minutes: minutes);
    if (!first && !calibrating && before == null) {
      for (final e in x.exercises) { ensureState(s, e.exercise)..appearances = 3..calibrating = false; }
    }
    startWorkout(s, x, at);
    var t = at;
    if (warmup > 0) { t = t.add(Duration(minutes: warmup)); ready(x, t); }
    final want = plan(x);
    for (var i = 0; i < x.exercises.length && i < want.length; i++) {
      if (want[i].isEmpty) break;
      for (final r in want[i]) {
        t = t.add(Duration(seconds: lift));
        if (calibrating) { logReps(s, x, r, t); } else { enterReps(x, r, t); }
        t = t.add(Duration(seconds: rest));
        ready(x, t);
      }
    }
    endWorkout(x, end == null ? t : at.add(Duration(minutes: end)));
    return x;
  }
  if (before != null) {
    final x0 = run(before, DateTime.now().subtract(const Duration(days: 2)), null);
    finishSession(s, x0, Finish(endRead: EndRead.done), x0.endedAt!);
  }
  s.active = run(reps, DateTime.now().subtract(const Duration(minutes: 60)), endAfter);
  return Store(s, null);
}

void main() {
  testWidgets('finish', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);

    List<int> top(SessionExercise e) => List.filled(e.sets.length, e.hi);
    List<int> under(SessionExercise e) => List.filled(e.sets.length, e.hi - 2);
    List<int> fade(SessionExercise e) => [for (var k = 0; k < e.sets.length; k++) e.hi - 2 * k];
    Future<void> fresh() => tester.pumpWidget(const SizedBox());

    // a first workout: every exercise new, the first ones levelling up
    await fresh();
    await snap(tester, play((x) => [for (final e in x.exercises) top(e)], first: true, warmup: 5, minutes: 60), 'f1-first');

    // a first workout with calibration sets: one found at once, one after the cap, one still looking
    await fresh();
    await snap(tester, play((x) => [[14, 10, 10], [calibrationCap, 9, 9], [calibrationCap, calibrationCap, calibrationCap]], calibrating: true, minutes: 60), 'f0-calibrated');

    // the second workout, stronger than the first: one level earned, more reps on the others
    await fresh();
    final stronger = play((x) => [top(x.exercises[0]), [for (final _ in x.exercises[1].sets) x.exercises[1].hi - 1], under(x.exercises[2])],
        before: (x) => [under(x.exercises[0]), under(x.exercises[1]), [for (final _ in x.exercises[2].sets) x.exercises[2].hi - 4]], warmup: 5, minutes: 60);
    await snap(tester, stronger, 'f2-stronger');
    await tester.tap(find.textContaining('LEVELLED UP').first); // the app's call, to change
    await settle(tester);
    await snap(tester, stronger, 'f2-change');

    // a finished day that faded: a kind word, no wins
    await fresh();
    await snap(tester, play((x) => [for (final e in x.exercises) fade(e)]), 'f3-low');

    // ended early with time and energy both possible: the one question
    await fresh();
    await snap(tester, play((x) => [top(x.exercises[0]), fade(x.exercises[1])], endAfter: 34), 'f4-ask');

    // the details behind the finish, an exercise's drawer, and the warm-up's
    await fresh();
    final d = play((x) => [top(x.exercises[0]), fade(x.exercises[1]), under(x.exercises[2])], warmup: 5, minutes: 60);
    await snap(tester, d, 'd1-finish');
    await tester.tap(find.text('Check or fix details'));
    await settle(tester);
    await snap(tester, d, 'd2-details');
    await tester.tap(find.text(d.state.active!.exercises[1].exercise.name).last);
    await settle(tester);
    await snap(tester, d, 'd3-drawer');
    await tester.tap(find.byIcon(LucideIcons.plus).first);
    await settle(tester);
    Navigator.of(tester.element(find.text('Set 1'))).pop();
    await settle(tester);
    await tester.tap(find.text('Warm-up'));
    await settle(tester);
    await snap(tester, d, 'd4-warmup');
    Navigator.of(tester.element(find.text('Took').last)).pop();
    await settle(tester);
    await tester.dragUntilVisible(find.text('Something hurt'), find.byType(ListView).first, const Offset(0, -300));
    await settle(tester);
    await tester.tap(find.text('Something hurt'));
    await settle(tester);
    await snap(tester, d, 'd5-hurt');
    expect(tester.takeException(), isNull);
  });
}
