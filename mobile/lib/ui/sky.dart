// The sky at the top of Today: a gradient and a sun that follow the time of day (logic/daylight.dart). The theme
// decides how bright the sky is (pale by day's theme, deep on black), the time decides its colour and where the sun
// sits. The sun stays at the right and only rises and sinks, so it never crosses the day's name; at night a crescent
// moon takes its place. The horizon is the bottom edge of whatever the sky is drawn behind: the first card sits on it.
import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../logic/daylight.dart';
import 'theme.dart';

/// One moment's sky: top, middle and horizon for each theme, then the sun (or moon): its size, how far its centre is
/// above the horizon, how far it sits in from the right edge (negative runs off it), and its colours top to bottom.
class _Look {
  const _Look(this.light, this.dark, this.size, this.rise, this.inset, this.orb, {this.moon = false});
  final List<Color> light, dark, orb;
  final double size, rise, inset;
  final bool moon;
}

const _moonLight = [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF)];
const _moonDark = [Color(0xFFE9E6FF), Color(0xFFE9E6FF), Color(0xFFE9E6FF)];
const _looks = <Daylight, _Look>{
  Daylight.dawn: _Look([Color(0xFFB7C2F2), Color(0xFFDCCDEB), Color(0xFFF8D2C0)], [Color(0xFF1E1670), Color(0xFF5A3BB5), Color(0xFFA0527F)],
      150, -28, -30, [Color(0xFFFFD98A), Color(0xFFFBA07A), Color(0xFFF58A7E)]),
  Daylight.morning: _Look([Color(0xFF86C5FA), Color(0xFFC6E1F8), Color(0xFFFBE6CE)], [Color(0xFF123C88), Color(0xFF2E6DC2), Color(0xFF6C74B8)],
      140, 26, -30, [Color(0xFFFFE38C), Color(0xFFFDB582), Color(0xFFFB9A86)]),
  Daylight.midday: _Look([Color(0xFF6DB7FA), Color(0xFFA9D5FC), Color(0xFFDCEEFD)], [Color(0xFF0B48A6), Color(0xFF2B7FDB), Color(0xFF4F97E6)],
      58, 74, 38, [Color(0xFFFFF1B0), Color(0xFFFFE48F), Color(0xFFFFD86E)]),
  Daylight.afternoon: _Look([Color(0xFF8EC3F2), Color(0xFFD9DDD8), Color(0xFFF9DCA8)], [Color(0xFF1D4B94), Color(0xFF6F6AA0), Color(0xFFC98A4F)],
      124, 30, -24, [Color(0xFFFFDD7C), Color(0xFFFBAB62), Color(0xFFF8925E)]),
  Daylight.sunset: _Look([Color(0xFF9A9BDC), Color(0xFFE2B3BE), Color(0xFFF8B79A)], [Color(0xFF2A1B6B), Color(0xFFA23E72), Color(0xFFE0683F)],
      150, -36, -30, [Color(0xFFFFB868), Color(0xFFF4705C), Color(0xFFE85C62)]),
  Daylight.night: _Look([Color(0xFFB9BFE6), Color(0xFFD6D5EE), Color(0xFFECE7F1)], [Color(0xFF070A1C), Color(0xFF0C1030), Color(0xFF080A1A)],
      48, 74, 44, _moonDark, moon: true),
};

/// An hour to show in place of the clock's, set from the Playground to look through the day; null follows the clock.
/// `--dart-define=SKY_HOUR=9` fixes it for a screenshot run.
final skyHour = ValueNotifier<double?>(double.tryParse(const String.fromEnvironment('SKY_HOUR')));

/// The sky at one instant, ready to paint.
class SkyNow {
  SkyNow(double hour, Brightness b) {
    final m = daylightMix(hour);
    final a = _looks[m.from]!, z = _looks[m.to]!;
    final dark = b == Brightness.dark;
    List<Color> mix(List<Color> x, List<Color> y) => [for (var i = 0; i < 3; i++) Color.lerp(x[i], y[i], m.t)!];
    sky = mix(dark ? a.dark : a.light, dark ? z.dark : z.light);
    if (a.moon == z.moon) {
      size = lerpDouble(a.size, z.size, m.t)!;
      rise = lerpDouble(a.rise, z.rise, m.t)!;
      inset = lerpDouble(a.inset, z.inset, m.t)!;
      moon = a.moon;
      orb = moon ? (dark ? _moonDark : _moonLight) : mix(a.orb, z.orb);
    } else {
      // sun to moon, or moon to sun: the first sinks below the horizon, then the second rises from it
      final first = m.t < 0.5;
      final k = first ? a : z;
      final under = -k.size / 2 - 6;
      size = k.size;
      inset = k.inset;
      rise = first ? lerpDouble(k.rise, under, m.t * 2)! : lerpDouble(under, k.rise, m.t * 2 - 1)!;
      moon = k.moon;
      orb = moon ? (dark ? _moonDark : _moonLight) : k.orb;
    }
  }
  late final List<Color> sky, orb;
  late final double size, rise, inset;
  late final bool moon;
}

/// [child] with the sky behind it: the gradient from the top of [child] to [tail] below it, where it has faded into the
/// page, and the sun resting on [child]'s bottom edge.
class SkyBehind extends StatefulWidget {
  const SkyBehind({super.key, required this.child, this.tail = 110});
  final Widget child;
  final double tail;
  @override
  State<SkyBehind> createState() => _SkyBehindState();
}

class _SkyBehindState extends State<SkyBehind> {
  Timer? tick;

  @override
  void initState() {
    super.initState();
    // the sky moves too slowly to animate: a new one each minute is enough
    tick = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
    skyHour.addListener(_changed);
  }

  void _changed() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    tick?.cancel();
    skyHour.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = SkyNow(skyHour.value ?? hourOf(DateTime.now()), Theme.of(context).brightness);
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(left: 0, right: 0, top: 0, bottom: -widget.tail, child: ExcludeSemantics(child: DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [...now.sky, context.du.bg], stops: const [0, 0.46, 0.74, 1]),
      )))),
      Positioned(right: 0, bottom: 0, width: 190, height: 150, child: ExcludeSemantics(child: ClipRect(child: CustomPaint(painter: _Orb(now))))),
      widget.child,
    ]);
  }
}

class _Orb extends CustomPainter {
  _Orb(this.now);
  final SkyNow now;
  @override
  void paint(Canvas canvas, Size size) {
    final r = now.size / 2;
    final c = Offset(size.width - now.inset - r, size.height - now.rise);
    final box = Rect.fromCircle(center: c, radius: r);
    final paint = Paint()..isAntiAlias = true;
    if (now.moon) {
      // a crescent: the disc with a second disc cut from its upper left
      paint.color = now.orb.first;
      final cut = Path()..addOval(Rect.fromCircle(center: c + Offset(-r * 0.52, -r * 0.2), radius: r));
      canvas.drawPath(Path.combine(PathOperation.difference, Path()..addOval(box), cut), paint);
    } else {
      paint.shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: now.orb, stops: const [0, 0.6, 1]).createShader(box);
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(_Orb old) => old.now != now;
}
