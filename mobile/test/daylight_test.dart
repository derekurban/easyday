import 'package:easyday/logic/daylight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each moment is fully there at its hour', () {
    for (final e in daylightAt.entries) {
      final m = daylightMix(e.value);
      expect(m.t == 0 ? m.from : m.to, e.key, reason: '${e.key} at ${e.value}');
      expect(m.t, 0, reason: 'nothing mixed in at ${e.value}');
    }
  });

  test('between two moments the sky is part of each, in order', () {
    final m = daylightMix(7.5);
    expect((m.from, m.to), (Daylight.dawn, Daylight.morning));
    expect(m.t, closeTo(0.5, 1e-9));
    final late = daylightMix(19.75);
    expect((late.from, late.to), (Daylight.sunset, Daylight.night));
    expect(late.t, closeTo(0.5, 1e-9));
  });

  test('night holds through midnight, then turns to dawn in its last hour', () {
    for (final h in [20.5, 23.0, 0.0, 2.5, 4.99]) {
      final m = daylightMix(h);
      expect((m.from, m.to, m.t), (Daylight.night, Daylight.night, 0.0), reason: 'at $h');
    }
    final m = daylightMix(5.5);
    expect((m.from, m.to), (Daylight.night, Daylight.dawn));
    expect(m.t, closeTo(0.5, 1e-9));
  });

  test('hours outside the day wrap, and a time reads as its hour', () {
    expect(daylightMix(33).to, daylightMix(9).to);
    expect(daylightMix(-1).from, Daylight.night);
    expect(hourOf(DateTime(2026, 11, 16, 16, 30)), 16.5);
    expect(daylightName(13), 'midday');
    expect(daylightName(8.9), 'morning');
  });
}
