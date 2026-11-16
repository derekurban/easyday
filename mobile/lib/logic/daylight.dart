// The time of day as the sky at the top of Today sees it: six moments, and where between two of them a clock time
// falls. The clock alone decides (no location, no real sunrise): the same sky at the same hour everywhere.

enum Daylight { dawn, morning, midday, afternoon, sunset, night }

/// The hour each moment is fully there. Night holds from its hour round to [nightEnds], then turns to dawn.
const daylightAt = {
  Daylight.dawn: 6.0, Daylight.morning: 9.0, Daylight.midday: 13.0, Daylight.afternoon: 16.5, Daylight.sunset: 19.0, Daylight.night: 20.5,
};
const nightEnds = 5.0;

/// Two moments and how far the sky is from the first to the second: 0 at [from], 1 at [to].
typedef DaylightMix = ({Daylight from, Daylight to, double t});

/// The mix at a clock [hour], 0 up to 24 (any other number wraps).
DaylightMix daylightMix(double hour) {
  final h = (hour % 24 + 24) % 24;
  if (h >= daylightAt[Daylight.night]! || h < nightEnds) return (from: Daylight.night, to: Daylight.night, t: 0);
  final dawn = daylightAt[Daylight.dawn]!;
  if (h < dawn) return (from: Daylight.night, to: Daylight.dawn, t: (h - nightEnds) / (dawn - nightEnds));
  const order = Daylight.values;
  for (var i = 0; i < order.length - 1; i++) {
    final a = daylightAt[order[i]]!, b = daylightAt[order[i + 1]]!;
    if (h < b) return (from: order[i], to: order[i + 1], t: (h - a) / (b - a));
  }
  return (from: Daylight.night, to: Daylight.night, t: 0);
}

/// A time as an hour of the day, minutes as its fraction.
double hourOf(DateTime t) => t.hour + t.minute / 60;

/// The moment the sky is nearest to, as a word.
String daylightName(double hour) {
  final m = daylightMix(hour);
  return (m.t < 0.5 ? m.from : m.to).name;
}
