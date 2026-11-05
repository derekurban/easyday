// Renders the Playground's tile lab in its states, light and dark, to PNG files, mid-animation too. Not part of the
// suite:   flutter test --run-skipped test/shots_playground_test.dart   (SHOTS_DIR sets the folder)
@Skip('Screenshots of the tile lab for review, not a check.')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:easyday/data/store.dart';
import 'package:easyday/ui/app.dart';
import 'package:easyday/ui/playground.dart';
import 'package:easyday/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shots_test.dart' show loadFonts, dir;
import 'workout_test.dart' show fresh;

void main() {
  testWidgets('tile lab', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 1500);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadFonts);
    final key = GlobalKey();
    Future<void> snap(String name) async {
      await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 2.5);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name.png')..createSync(recursive: true)..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    Future<void> frames([int n = 8]) async { for (var k = 0; k < n; k++) { await tester.pump(const Duration(milliseconds: 250)); } }
    await tester.pumpWidget(RepaintBoundary(key: key, child: StoreScope(store: Store(fresh(), null), child: MaterialApp(
        debugShowCheckedModeBanner: false, theme: buildTheme(Brightness.dark), home: const PlaygroundScreen()))));
    // the arrival: the earned step ups burst as the tiles come in
    await tester.pump(const Duration(milliseconds: 500));
    await snap('p1-arrival-mid');
    await frames();
    await snap('p2-heart-chip');
    // the chip opened, a step up on the curl: mid-burst, then settled
    await tester.tap(find.text('12 kg'));
    await frames(2);
    await tester.tap(find.byIcon(LucideIcons.plus).first);
    await tester.pump(const Duration(milliseconds: 16));
    var at = 16;
    for (final ms in [100, 250, 400, 600, 900]) {
      await tester.pump(Duration(milliseconds: ms - at));
      at = ms;
      await snap('p3-step-up-${ms}ms');
    }
    await frames();
    await snap('p4-chip-step-up');
    // the take
    await tester.tap(find.byIcon(LucideIcons.heart));
    await frames();
    await snap('p9-take-love');
    await tester.tap(find.byTooltip('Light'));
    await frames();
    await snap('p12-light');
    expect(tester.takeException(), isNull);
  });
}
