import 'package:easyday/data/model.dart';
import 'package:easyday/data/store.dart';
import 'package:easyday/ui/app.dart';
import 'package:easyday/ui/theme.dart';
import 'package:easyday/ui/today.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'muscle_plan_test.dart' as fixture;

void main() {
  testWidgets('Today exposes both draws, Back, Reset and ordered swaps on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = fixture.fresh(template: 'gym');
    s.settings.timeLimit = false;
    final store = Store(s, null);
    await tester.pumpWidget(StoreScope(store: store, child: MaterialApp(
      theme: buildTheme(Brightness.light), home: const TodayScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Start workout'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pumpAndSettle();
    expect(find.text('Shuffle exercises'), findsOneWidget);
    expect(find.text('Shuffle muscles'), findsOneWidget);
    await tester.tap(find.text('Shuffle exercises'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Shuffle'));
    await tester.pumpAndSettle();
    expect(find.text('Draw again'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Muscles'));
    await tester.pumpAndSettle();
    expect(find.text('Manual'), findsOneWidget);
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to work'), findsOneWidget);
    final start = tester.widget<FilledButton>(find.ancestor(of: find.text('Start workout'), matching: find.byType(FilledButton)));
    expect(start.onPressed, isNull);
    expect(tester.takeException(), isNull);
    expect(s.active, isNull);
    expect(s.sessions, isEmpty);
    expect(s.goal, isA<GoalConfig>());
  });
}
