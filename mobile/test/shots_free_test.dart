// Renders free form, the order chip and sheet, and the weight and version wheels, light and dark, to PNG files for
// review. Not part of the suite: run with  flutter test --run-skipped test/shots_free_test.dart  and SHOTS_DIR set.
@Skip('Screenshots of free form and the weight wheel for review, not a check: flutter test --run-skipped test/shots_free_test.dart with SHOTS_DIR set.')
library;

import 'package:easyday/data/model.dart';
import 'package:easyday/data/store.dart';
import 'package:easyday/logic/workout.dart';
import 'package:easyday/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features_test.dart' as f;
import 'shots_app_test.dart' show shoot;
import 'shots_test.dart' show loadFonts, settle, snap;
import 'workout_test.dart' as w;

void main() {
  testWidgets('free form', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);

    final s = w.fresh(template: 'gym');
    final x = w.build(s, warmup: 0, order: WorkoutOrder.free);
    final start = DateTime.now().subtract(const Duration(minutes: 3));
    startWorkout(s, x, start);
    s.active = x;
    final store = Store(s, null);

    await snap(tester, store, 'f1-choose-first');
    await tester.tap(find.text(x.exercises[1].exercise.name).first); // the second one first: the order is the user's
    await settle(tester);
    await snap(tester, store, 'f2-lift-weight');
    await tester.tap(find.byKey(const ValueKey('level')));
    await settle(tester);
    await snap(tester, store, 'f3a-weight-drawer');
    await tester.drag(find.byType(ListWheelScrollView).last, const Offset(0, -96));
    await settle(tester);
    await snap(tester, store, 'f3b-weight-drawer-changed');
    await tester.tap(find.text('Done'));
    await settle(tester);
    await snap(tester, store, 'f3c-weight-changed');
    await tester.tap(find.textContaining('Log '));
    await settle(tester);
    await snap(tester, store, 'f4-rest');

    // the rest of that exercise, and one set of another, then Ready: the list again, with the finished one under Done
    final now = DateTime.now();
    store.update((_) {
      for (var k = 1; k < x.exercises[1].sets.length; k++) {
        ready(x, now.add(Duration(seconds: k * 40)), pick: 1);
        enterReps(x, x.exercises[1].hi - 1, now.add(Duration(seconds: k * 40 + 20)));
      }
      ready(x, now.add(const Duration(seconds: 150)), pick: 0);
      enterReps(x, x.exercises[0].hi, now.add(const Duration(seconds: 170)));
    });
    await settle(tester);
    await tester.tap(find.byType(FilledButton).last);
    await settle(tester);
    await snap(tester, store, 'f5-choose-next');

    await tester.tap(find.text('Free form'));
    await settle(tester);
    await snap(tester, store, 'f6-order-sheet');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('version wheel', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);

    final s = w.fresh(template: 'none'); // no equipment: bodyweight versions
    final x = w.build(s, warmup: 0, order: WorkoutOrder.free);
    final i = x.exercises.indexWhere((e) => !e.exercise.loaded && e.exercise.ladder != null);
    expect(i, greaterThanOrEqualTo(0));
    startWorkout(s, x, DateTime.now().subtract(const Duration(minutes: 2)));
    ready(x, DateTime.now().subtract(const Duration(seconds: 20)), pick: i);
    s.active = x;
    final store = Store(s, null);
    await snap(tester, store, 'f7a-version-row');
    await tester.tap(find.byKey(const ValueKey('level')));
    await settle(tester);
    await snap(tester, store, 'f7b-version-drawer');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('the plan', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);
    final s = f.fresh(template: 'gym')..settings.order = WorkoutOrder.free;
    final now = DateTime.now();
    for (final d in [9, 7, 5, 3]) { f.run(s, now.subtract(Duration(days: d, hours: 2))); }
    final store = Store(s, null);
    await shoot(tester, store, () => const Shell(), 'f8-today-plan', height: 2000, then: () async { await tester.tap(find.text('Lift instead')); });
    await shoot(tester, store, () => const Shell(), 'f9-today-order-sheet', height: 1100, then: () async {
      await tester.tap(find.text('Lift instead'));
      for (var k = 0; k < 6; k++) { await tester.pump(const Duration(milliseconds: 250)); }
      await tester.scrollUntilVisible(find.text('Free form'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Free form'));
    });
    expect(tester.takeException(), isNull);
  });
}
