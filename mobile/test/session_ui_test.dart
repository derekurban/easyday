import 'package:easyday/data/store.dart';
import 'package:easyday/logic/workout.dart';
import 'package:easyday/ui/app.dart';
import 'package:easyday/ui/session.dart';
import 'package:easyday/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test.dart' as w;

/// The workout screen: looking back and ahead, changing a done set, pausing without an overlay.
void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> swipe(WidgetTester tester, {required bool back}) async {
    await tester.fling(find.byType(ListView).first, Offset(back ? 300 : -300, 0), 1500);
    await settle(tester);
  }

  testWidgets('look back at a done set, change it, look ahead, come back to now', (tester) async {
    tester.view.physicalSize = const Size(412, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = w.fresh(template: 'gym');
    final x = w.build(s, warmup: 0);
    startWorkout(s, x, DateTime.now().subtract(const Duration(seconds: 40)));
    s.active = x;
    await tester.pumpWidget(StoreScope(store: Store(s, null), child: MaterialApp(theme: buildTheme(Brightness.dark), home: const SessionScreen())));
    await settle(tester);
    final e = x.exercises[0];

    // log the first set, then rest
    await tester.tap(find.textContaining('Log '));
    await settle(tester);
    expect(find.text('Rest'), findsWidgets);
    expect(e.sets[0].reps, e.hi);

    // back: the set just done, on a wheel to change
    await swipe(tester, back: true);
    expect(find.textContaining('Update the previous'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);
    expect(find.textContaining('Save '), findsNothing);
    await tester.drag(find.byType(ListWheelScrollView), const Offset(58, 0)); // one number down: saved as it turns
    await settle(tester);
    expect(e.sets[0].reps, e.hi - 1);
    expect(find.textContaining('Set 1 of ${e.sets.length} · ${e.hi - 1}'), findsOneWidget);

    // Return comes back to the rest
    await tester.tap(find.text('Return'));
    await settle(tester);
    expect(find.textContaining('Update the previous'), findsNothing);
    expect(find.textContaining('Start set 2'), findsOneWidget);

    // ahead: the next set, coming up; looking does not start it
    await swipe(tester, back: false);
    expect(find.text('Coming up'), findsOneWidget);
    expect(e.sets[1].start, isNull);
    await tester.tap(find.text('Return'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause keeps the screen and turns the main button off; End is an X', (tester) async {
    tester.view.physicalSize = const Size(412, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = w.fresh(template: 'gym');
    final x = w.build(s, warmup: 0);
    startWorkout(s, x, DateTime.now().subtract(const Duration(seconds: 40)));
    s.active = x;
    await tester.pumpWidget(StoreScope(store: Store(s, null), child: MaterialApp(theme: buildTheme(Brightness.dark), home: const SessionScreen())));
    await settle(tester);
    expect(find.byTooltip('End workout'), findsOneWidget);

    // the time itself is the pause button
    await tester.tap(find.textContaining(RegExp(r'^\d+:\d\d$')));
    await settle(tester);
    expect(x.pausedAt, isNotNull);
    expect(find.text('Paused'), findsOneWidget);
    final log = tester.widget<FilledButton>(find.ancestor(of: find.text('Paused'), matching: find.byType(FilledButton)));
    expect(log.onPressed, isNull);
    expect(find.text(x.exercises[0].exercise.ladder != null ? x.exercises[0].rungLabel : x.exercises[0].exercise.name), findsOneWidget);

    await tester.tap(find.textContaining('paused'));
    await settle(tester);
    expect(x.pausedAt, isNull);
    expect(find.textContaining('Log '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Log waits once as a set arrives: not again on coming back to it, and not when paused', (tester) async {
    tester.view.physicalSize = const Size(412, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = w.fresh(template: 'gym');
    final x = w.build(s, warmup: 0);
    startWorkout(s, x, DateTime.now().subtract(const Duration(seconds: 5)));
    s.active = x;
    await tester.pumpWidget(StoreScope(store: Store(s, null), child: MaterialApp(theme: buildTheme(Brightness.dark), home: const SessionScreen())));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Do your set'), findsOneWidget, reason: 'the set has just begun');

    // pausing mid-wait ends it; resuming does not start it again
    await tester.tap(find.textContaining(RegExp(r'^\d+:\d\d$')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400)); // the wait's fade out
    expect(find.text('Do your set'), findsNothing);
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.textContaining('paused'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Do your set'), findsNothing);
    expect(find.textContaining('Log '), findsOneWidget);

    // look ahead and come back: Log is there at once
    await tester.fling(find.byType(ListView).first, const Offset(-300, 0), 1500);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Return'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Do your set'), findsNothing);
    expect(find.textContaining('Log '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
