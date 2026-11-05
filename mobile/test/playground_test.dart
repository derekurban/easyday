import 'package:easyday/data/store.dart';
import 'package:easyday/ui/app.dart';
import 'package:easyday/ui/playground.dart';
import 'package:easyday/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'workout_test.dart' as w;

void main() {
  testWidgets('the tile lab: a weight chip opens easier, the same and harder; a first time takes your take', (tester) async {
    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final real = Store(w.fresh(), null);
    await tester.pumpWidget(StoreScope(store: real, child: MaterialApp(theme: buildTheme(Brightness.dark), home: const PlaygroundScreen())));
    Future<void> frames() async { for (var k = 0; k < 6; k++) { await tester.pump(const Duration(milliseconds: 250)); } }
    await frames();
    // the curl's chip: open it, harder (a step up, its label and weight), easier, the same
    await tester.tap(find.text('12 kg'));
    await frames();
    expect(find.text('Next time'), findsOneWidget);
    expect(find.text('Same'), findsOneWidget, reason: 'the picked pill opens with its word');
    await tester.tap(find.byIcon(LucideIcons.plus));
    await frames();
    expect(find.text('Harder'), findsOneWidget);
    expect(find.text('STEPPING UP'), findsOneWidget);
    expect(find.text('13 kg'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.minus));
    await frames();
    expect(find.text('Easier'), findsOneWidget);
    expect(find.text('11 kg'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.equal));
    await frames();
    // the take, on the first time
    expect(find.text("It's fine"), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.heart));
    await frames();
    expect(find.text('Love it'), findsOneWidget);
    await tester.tap(find.byTooltip('Light'));
    await frames();
    expect(tester.takeException(), isNull);
    expect(real.state.sessions, isEmpty, reason: 'the lab never touches the real data');
  });
}
