import 'package:easyday/data/store.dart';
import 'package:easyday/ui/app.dart';
import 'package:easyday/ui/logged.dart';
import 'package:easyday/ui/playground.dart';
import 'package:easyday/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test.dart' as w;

void main() {
  testWidgets('every sample in the playground opens the finish screen, and Done comes back', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final real = Store(w.fresh(), null);
    await tester.pumpWidget(StoreScope(store: real, child: MaterialApp(theme: buildTheme(Brightness.light), home: const PlaygroundScreen())));
    Future<void> frames() async { for (var k = 0; k < 4; k++) { await tester.pump(const Duration(milliseconds: 500)); } }
    final n = find.byType(ListTile).evaluate().length;
    expect(n, greaterThanOrEqualTo(8));
    for (var i = 0; i < n; i++) {
      await tester.scrollUntilVisible(find.byType(ListTile).at(i), 200);
      final title = tester.widget<Text>(find.descendant(of: find.byType(ListTile).at(i), matching: find.byType(Text)).first).data;
      await tester.tap(find.byType(ListTile).at(i));
      await frames();
      expect(tester.takeException(), isNull, reason: 'sample $i');
      expect(find.byType(LoggedView), findsOneWidget, reason: 'sample $i');
      // only the samples that ended before the plan was done ask why
      final early = title == 'Out of time' || title == 'It has to ask';
      expect(find.text('You finished early').evaluate().isNotEmpty, early, reason: '$title');
      await tester.tap(find.text('Done'));
      await frames();
      expect(find.byType(LoggedView), findsNothing, reason: 'back from sample $i');
    }
    expect(real.state.sessions, isEmpty, reason: 'the samples never touch the real data');
    expect(real.state.active, isNull);
  });
}
