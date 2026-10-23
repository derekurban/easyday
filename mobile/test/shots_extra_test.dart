// States that only exist after the overhaul: paused, looking back at a done set, an open accordion.
@Skip('Screenshots of the workout screen after the overhaul for review, not a check: flutter test --run-skipped test/shots_extra_test.dart with SHOTS_DIR set.')
library;

import 'package:easyday/data/store.dart';
import 'package:easyday/logic/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shots_test.dart';
import 'workout_test.dart' as w;

void main() {
  testWidgets('extras', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);

    final s = w.fresh(template: 'gym');
    final x = w.build(s, warmup: 5);
    startWorkout(s, x, DateTime.now().subtract(const Duration(seconds: 40)));
    s.active = x;
    final store = Store(s, null);
    final e = x.exercises[0];

    await tester.pumpWidget(app(store, Brightness.dark));
    await settle(tester);
    await tester.tap(find.text('Cat-cow'));          // accordion open
    await settle(tester);
    await snap(tester, store, '7-warmup-accordion');
    await tapMain(tester);
    await logTop(tester, e.hi);                      // resting
    await tester.tap(find.byTooltip('Pause'));       // paused in rest
    await settle(tester);
    await snap(tester, store, '8-rest-paused');
    await tester.tap(find.byTooltip('Resume'));
    await settle(tester);
    await tester.tap(find.text('Fix the last set')); // the done set on the wheel
    await settle(tester);
    await snap(tester, store, '9-fix-last-set');
    await tester.tap(find.text('Return'));
    await settle(tester);
    await tester.fling(find.byType(ListView).first, const Offset(-300, 0), 1500); // look ahead
    await settle(tester);
    await snap(tester, store, '10-look-ahead');
    expect(tester.takeException(), isNull);
  });
}
