// Renders every other screen of the app with three weeks of history, light and dark, to PNG files for review.
@Skip('Screenshots of every other screen for review, not a check: flutter test --run-skipped test/shots_app_test.dart with SHOTS_DIR set.')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easyday/data/index.dart';
import 'package:easyday/data/library.dart';
import 'package:easyday/data/model.dart';
import 'package:easyday/data/store.dart';
import 'package:easyday/logic/builder.dart';
import 'package:easyday/logic/muscle_map.dart';
import 'package:easyday/logic/muscle_plan.dart';
import 'package:easyday/logic/workout.dart';
import 'package:easyday/ui/app.dart';
import 'package:easyday/ui/exercise_card.dart';
import 'package:easyday/ui/goal_editor.dart';
import 'package:easyday/ui/how.dart';
import 'package:easyday/ui/location_editor.dart';
import 'package:easyday/ui/muscle_picker.dart';
import 'package:easyday/ui/progress.dart';
import 'package:easyday/ui/strain_timeline.dart';
import 'package:easyday/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features_test.dart' as f;
import 'shots_test.dart' show loadFonts, dir;

final _key = GlobalKey();

Widget wrap(Store store, Brightness b, Widget home) => RepaintBoundary(
    key: _key,
    child: StoreScope(store: store, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(b), home: home)));

Future<void> pumpSome(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> shoot(WidgetTester tester, Store store, Widget Function() home, String name, {double height = 915, Future<void> Function()? then}) async {
  tester.view.physicalSize = Size(412, height);
  for (final b in [Brightness.dark, Brightness.light]) {
    await tester.pumpWidget(wrap(store, b, home()));
    await pumpSome(tester);
    if (then != null) { await then(); await pumpSome(tester); }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400))); // let images load
    await pumpSome(tester);
    await tester.runAsync(() async {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name-${b.name}.png')..createSync(recursive: true)..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }
}

void main() {
  testWidgets('app screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);

    // three weeks of history, every other day or so, the last one three days ago
    final s = f.fresh(template: 'gym');
    final now = DateTime.now();
    final sessions = <Session>[];
    for (final d in [21, 19, 16, 14, 12, 9, 7, 5, 3]) {
      sessions.add(f.run(s, now.subtract(Duration(days: d, hours: 2))));
    }
    final exId = sessions.last.exercises.first.exId;
    final store = Store(s, null);

    await shoot(tester, store, () => const Shell(), '20-today', height: 1500);
    await shoot(tester, store, () => const Shell(), '20-today-lift', height: 2000, then: () async { await tester.tap(find.text('Lift instead')); });
    await shoot(tester, store, () => const Shell(), '21-progress', height: 2200, then: () async { await tester.tap(find.text('Progress')); });
    await shoot(tester, store, () => const Shell(), '22-exercises', height: 1800, then: () async { await tester.tap(find.text('Exercises')); });
    await shoot(tester, store, () => const Shell(), '23-settings', height: 3200, then: () async { await tester.tap(find.text('Settings')); });
    await shoot(tester, store, () => ExerciseCardScreen(exId), '24-exercise-card', height: 1700);
    await shoot(tester, store, () => ExerciseProgressScreen(exId), '25-exercise-progress', height: 1500);
    await shoot(tester, store, () => const StrainTimelineScreen(), '26-strain-timeline', height: 1200);
    await shoot(tester, store, () => const HowItWorks(), '27-how-it-works', height: 2000);
    await shoot(tester, store, () => Scaffold(appBar: AppBar(title: const Text('Goal')), body: ListView(padding: const EdgeInsets.all(16), children: [GoalEditor(goal: s.goal!, onChanged: (_) {})])), '28-goal-editor', height: 2600);
    await shoot(tester, store, () => Scaffold(appBar: AppBar(title: const Text('Location')), body: ListView(padding: const EdgeInsets.all(16), children: [LocationEditor(location: s.locations.first, onChanged: () {})])), '29-location-editor', height: 1800);

    BuildOptions opts(MusclePlan p) => BuildOptions(energy: Energy.normal, minutes: 45, locationId: 'l1', muscles: p.forced, excluded: p.excluded, muscleSeed: p.muscleDraw, exerciseSeed: p.exerciseDraw, manual: p.manual, requirements: p.requirements);
    await shoot(tester, store, () => MusclePickerScreen(
      plan: MusclePlan(states: defaultMuscleStates(MuscleMap(s).currentStrainPoints(now), s.goal), order: trackedMuscles),
      preview: (p) => buildSession(s, opts(p), now),
      drawMuscles: (p) => nextMuscleSeed(s, opts(p), now),
    ), '30-muscle-picker', height: 1300);

    // Today's exercise sheet: tap the first exercise row
    await shoot(tester, store, () => const Shell(), '31-today-exercise-sheet', height: 1500, then: () async {
      await tester.tap(find.text('Lift instead'));
      await pumpSome(tester);
      for (final e in exerciseById.values) {
        if (find.text(e.name).evaluate().isNotEmpty) { await tester.tap(find.text(e.name).first); break; }
      }
    });

    // the end of a workout: feel, then the log
    final x = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 45, locationId: 'l1', liftInstead: true), now);
    startWorkout(s, x, now.subtract(const Duration(minutes: 38)));
    for (var i = 0; i < x.exercises.length; i++) {
      for (var k = 0; k < x.exercises[i].sets.length; k++) {
        ready(x, now.subtract(Duration(minutes: 36 - i * 8 - k * 2)));
        enterReps(x, x.exercises[i].target, now.subtract(Duration(minutes: 35 - i * 8 - k * 2)));
      }
    }
    s.active = x;
    await shoot(tester, store, () => const Shell(), '32-feel', then: () async {
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.byType(FilledButton).last); // Finish workout, or the next part
      await tester.pump(const Duration(seconds: 4));
      if (find.text('How was it?').evaluate().isEmpty) { await tester.tap(find.byType(FilledButton).last); await tester.pump(const Duration(seconds: 4)); }
    });
    await shoot(tester, store, () => const Shell(), '33-logged', height: 1600, then: () async {
      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump(const Duration(seconds: 4));
      if (find.text('How was it?').evaluate().isEmpty) { await tester.tap(find.byType(FilledButton).last); await tester.pump(const Duration(seconds: 4)); }
      await tester.tap(find.text('About right'));
      await tester.pump(const Duration(seconds: 1));
      if (find.text('Continue').evaluate().isNotEmpty) { await tester.tap(find.text('Continue')); await tester.pump(const Duration(seconds: 1)); }
    });
    store.update((st) => st.active = null);
    await shoot(tester, store, () => const Shell(), '34-today-done', height: 1300);

    // onboarding, every page
    final fresh = Store(AppState(), null);
    for (var i = 0; i < 5; i++) {
      await shoot(tester, fresh, () => const Shell(), '35-onboarding-$i', height: 1700, then: () async {
        for (var k = 0; k < i; k++) { await tester.tap(find.byType(FilledButton).last); await pumpSome(tester); }
      });
    }
    expect(tester.takeException(), isNull);
  });
}
