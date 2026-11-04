import 'package:easyday/data/library.dart';
import 'package:easyday/data/store.dart';
import 'package:easyday/ui/app.dart';
import 'package:easyday/ui/logged.dart';
import 'package:easyday/ui/playground.dart';
import 'package:easyday/ui/strength_lab.dart';
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
    final list = find.byType(Scrollable).first;
    // the strength rating first: each opens, and back
    for (final (id, _) in strengthLabExercises) {
      final name = find.text(exerciseById[id]!.name);
      await tester.scrollUntilVisible(name, 200, scrollable: list);
      await tester.tap(name);
      await frames();
      expect(tester.takeException(), isNull, reason: id);
      expect(find.byType(StrengthLabScreen), findsOneWidget);
      await tester.pageBack();
      await frames();
    }
    expect(playgroundSampleTitles.length, greaterThanOrEqualTo(8));
    // the finish screen is kept closed until opened
    expect(find.text(playgroundSampleTitles.first), findsNothing);
    await tester.scrollUntilVisible(find.text('Finish screen'), 200, scrollable: list);
    await tester.tap(find.text('Finish screen'));
    await frames();
    for (final title in playgroundSampleTitles) {
      await tester.scrollUntilVisible(find.text(title), 200, scrollable: list);
      await tester.tap(find.text(title));
      await frames();
      expect(tester.takeException(), isNull, reason: title);
      expect(find.byType(LoggedView), findsOneWidget, reason: title);
      // only the samples that ended before the plan was done ask why
      final early = title == 'Out of time' || title == 'It has to ask';
      expect(find.text('You finished early').evaluate().isNotEmpty, early, reason: title);
      await tester.tap(find.text('Done'));
      await frames();
      expect(find.byType(LoggedView), findsNothing, reason: 'back from $title');
    }
    expect(real.state.sessions, isEmpty, reason: 'the samples never touch the real data');
    expect(real.state.active, isNull);
  });
}
