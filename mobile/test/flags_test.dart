import 'package:easyday/data/model.dart';
import 'package:easyday/data/store.dart';
import 'package:easyday/features.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prototype tools', () {
    test('ship in staging only', () {
      expect(prototypeToolsFor('staging'), isTrue);
      expect(prototypeToolsFor('prod'), isFalse);
      expect(prototypeToolsFor(null), isFalse);
    });

    test('the clock shift applies only where the tools do', () {
      final s = AppState()..clockOffsetDays = 7;
      final shifted = Store(s, null, shiftClock: true).now.difference(DateTime.now()).inHours;
      final real = Store(s, null, shiftClock: false).now.difference(DateTime.now()).inHours;
      expect(shifted, closeTo(7 * 24, 1));
      expect(real, 0);
    });
  });
}
