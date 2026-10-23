// Renders the workout screen in a fixed set of states, light and dark, to PNG files, so two commits can be compared
// by eye. Not part of the suite: run with  flutter test test/shots_test.dart  and SHOTS_DIR set.
@Skip('Screenshots of the workout screen for review, not a check: flutter test --run-skipped test/shots_test.dart with SHOTS_DIR set.')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easyday/data/model.dart';
import 'package:easyday/data/store.dart';
import 'package:easyday/logic/builder.dart';
import 'package:easyday/logic/workout.dart';
import 'package:easyday/ui/app.dart';
import 'package:easyday/ui/session.dart';
import 'package:easyday/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test.dart' as w;

final dir = Platform.environment['SHOTS_DIR'] ?? 'build/shots';
const lucide = 'D:/pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.25/assets/lucide.ttf';

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      final b = await File(f).readAsBytes();
      l.addFont(Future.value(ByteData.sublistView(b)));
    }
    await l.load();
  }
  await load('Albert Sans', [for (final w in [300, 400, 500, 600]) 'assets/fonts/AlbertSans-$w.ttf']);
  await load('Wix Madefor Text', [for (final w in [400, 500, 600]) 'assets/fonts/WixMadeforText-$w.ttf']);
  await load('packages/lucide_icons_flutter/Lucide', [lucide]);
}

final key = GlobalKey();

Widget app(Store store, Brightness b) => RepaintBoundary(
    key: key,
    child: StoreScope(store: store, child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(b), home: const SessionScreen())));

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> snap(WidgetTester tester, Store store, String name) async {
  for (final b in [Brightness.dark, Brightness.light]) {
    await tester.pumpWidget(app(store, b));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name-${b.name}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
}

/// The main button in the dock, whatever it is called.
Future<void> tapMain(WidgetTester tester) async {
  await settle(tester);
  await tester.tap(find.byType(FilledButton).last);
  await settle(tester);
}

/// Log the top of the range: the Log button on the wheel, or the number's button in the row.
Future<void> logTop(WidgetTester tester, int hi) async {
  await settle(tester);
  final wheel = find.textContaining('Log ');
  if (wheel.evaluate().isNotEmpty) {
    await tester.tap(wheel);
  } else {
    await tester.tap(find.widgetWithText(OutlinedButton, '$hi').first);
  }
  await settle(tester);
}

void main() {
  testWidgets('shots', (tester) async {
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

    await snap(tester, store, '1-warmup');
    await tapMain(tester);                 // the first exercise, set 1 lifting
    await snap(tester, store, '2-lift-set1');
    await logTop(tester, e.hi);            // resting after set 1
    await snap(tester, store, '3-rest');
    await tapMain(tester);                 // set 2 lifting
    await snap(tester, store, '4-lift-set2');
    store.update((_) => jumpTo(x, 'stretch', store.now));
    await settle(tester);
    await snap(tester, store, '5-stretch');
    expect(tester.takeException(), isNull);
  });

  testWidgets('move days', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);
    for (final kind in ['cardio', 'mobility']) {
      final s = w.fresh(template: 'gym');
      final x = buildSession(s, BuildOptions(energy: Energy.normal, minutes: 20, warmupMinutes: 0, moveKind: kind), w.t0);
      startWorkout(s, x, DateTime.now().subtract(const Duration(seconds: 40)));
      s.active = x;
      final store = Store(s, null);
      await snap(tester, store, '6-day-$kind');
      await tester.pumpWidget(const SizedBox());
    }
    expect(tester.takeException(), isNull);
  });
}
