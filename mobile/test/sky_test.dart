import 'package:easyday/ui/sky.dart';
import 'package:easyday/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the sky can be worked out at every quarter hour, in both themes', () {
    for (final b in Brightness.values) {
      for (var q = 0; q < 96; q++) {
        final now = SkyNow(q / 4, b);
        expect(now.sky, hasLength(3), reason: 'at ${q / 4}');
        expect(now.orb, hasLength(3), reason: 'at ${q / 4}');
        expect(now.size, greaterThan(0));
      }
    }
  });

  test('a moon by night, a sun by day, and between them the first sinks before the second rises', () {
    expect(SkyNow(23, Brightness.dark).moon, isTrue);
    expect(SkyNow(13, Brightness.dark).moon, isFalse);
    // sunset to night: still the sun in the first half, going under; the moon in the second, coming up
    final sinking = SkyNow(19.5, Brightness.light), rising = SkyNow(20.25, Brightness.light);
    expect(sinking.moon, isFalse);
    expect(sinking.rise, lessThan(SkyNow(19, Brightness.light).rise));
    expect(rising.moon, isTrue);
    expect(rising.rise, lessThan(SkyNow(21, Brightness.light).rise));
  });

  testWidgets('the sky paints behind its child at night and by day', (tester) async {
    for (final hour in [2.0, 9.0, 19.75]) {
      skyHour.value = hour;
      for (final b in Brightness.values) {
        await tester.pumpWidget(MaterialApp(theme: buildTheme(b), home: const Scaffold(body: SkyBehind(child: SizedBox(height: 200, child: Text('Today'))))));
        expect(find.text('Today'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'at $hour, $b');
      }
    }
    skyHour.value = null;
  });
}
