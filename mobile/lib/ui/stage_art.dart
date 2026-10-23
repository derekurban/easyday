// Stage art: a small looping picture of the kind of work under way, so strength, power, stability, cardio, stretching,
// the warm-up and rest each look like themselves at a glance. Drawn, not timed: nothing here counts anything down.
// Every drawing stays inside its panel and keeps to the design system's soft, rounded shapes
// (test/stage_art_test.dart checks the bounds).
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/library.dart';
import 'motion.dart';
import 'theme.dart';

export 'widgets.dart' show HowToSteps;

enum Stage { strength, power, stability, cardio, stretching, warmup, rest }

Stage stageOf(ExerciseType t) => switch (t) {
      ExerciseType.strength => Stage.strength,
      ExerciseType.power => Stage.power,
      ExerciseType.stability => Stage.stability,
      ExerciseType.cardio => Stage.cardio,
      ExerciseType.stretching => Stage.stretching,
    };

const _words = {
  Stage.strength: ('Strength', 'Slow and controlled'),
  Stage.power: ('Power', 'Explode, then reset'),
  Stage.stability: ('Stability', 'Still and steady'),
  Stage.cardio: ('Cardio', 'A pace you can talk at'),
  Stage.stretching: ('Stretching', 'Ease in, breathe out'),
  Stage.warmup: ('Warm-up', 'Loosen up'),
  Stage.rest: ('Rest', 'Breathe and recover'),
};

/// Each stage's loop length in milliseconds.
const _periods = {
  Stage.strength: 6000,
  Stage.power: 5000,
  Stage.stability: 18333,
  Stage.cardio: 2000,
  Stage.stretching: 6000,
  Stage.warmup: 12000,
  Stage.rest: 8000,
};

/// The height every drawing has to fit in.
const stageArtHeight = 116.0;

/// The gap between a picture and the line of words under it; the workout strip uses it under its blocks too.
const stageCaptionGap = 10.0;

/// The stage's picture, and under it its word on the left and its tagline on the right.
class StageArt extends StatefulWidget {
  const StageArt({super.key, required this.stage});
  final Stage stage;
  @override
  State<StageArt> createState() => _StageArtState();
}

class _StageArtState extends State<StageArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _period);

  Duration get _period => Duration(milliseconds: _periods[widget.stage]!);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _run();
  }

  @override
  void didUpdateWidget(StageArt old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) {
      _c.duration = _period;
      _c.value = 0;
      _run();
    }
  }

  void _run() {
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) {
      _c.stop();
      _c.value = 0.3;
    } else {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final (word, line) = _words[widget.stage]!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(color: du.sunk, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedSwitcher(
          duration: m(context, durSlow),
          child: SizedBox(
            key: ValueKey(widget.stage),
            height: stageArtHeight,
            width: double.infinity,
            child: CustomPaint(painter: _StagePainter(widget.stage, _c,
                _Ink(du.accentStrong, du.accentLine, du.accentSubtle, du.line, du.inkTertiary, du.ink))),
          ),
        ),
        const SizedBox(height: stageCaptionGap),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(word, style: t.labelLarge?.copyWith(color: du.inkSecondary)),
          const SizedBox(width: 16),
          Expanded(child: Text(line, textAlign: TextAlign.end, style: t.bodySmall?.copyWith(color: du.inkTertiary))),
        ]),
      ]),
    );
  }
}

/// Draws one moment of a stage with nothing clipped, for the bounds test.
@visibleForTesting
void debugPaintStage(Canvas canvas, Size size, Stage stage, double t) =>
    _StagePainter(stage, AlwaysStoppedAnimation(t),
            const _Ink(Color(0xFF8AB07C), Color(0xFF3E5A36), Color(0xFF1E2A1B), Color(0xFF333333), Color(0xFF777777), Color(0xFFEEEEEE)))
        ._draw(canvas, size, t);

class _Ink {
  const _Ink(this.strong, this.soft, this.faint, this.line, this.muted, this.ink);
  final Color strong, soft, faint, line, muted, ink;
  /// A light touch for sheen on a filled shape.
  Color get sheen => Color.lerp(strong, ink, 0.55)!;
}

class _StagePainter extends CustomPainter {
  _StagePainter(this.stage, this.anim, this.ink) : super(repaint: anim);
  final Stage stage;
  final Animation<double> anim;
  final _Ink ink;

  static double _ease(double x) => Curves.easeInOut.transform(x.clamp(0.0, 1.0));
  static double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
  /// The breath: four counts in, four counts out.
  static double _breath(double t) {
    final u = t - t.floorToDouble();
    return _ease(u < 0.5 ? u / 0.5 : 1 - (u - 0.5) / 0.5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _draw(canvas, size, anim.value);
  }

  void _draw(Canvas canvas, Size size, double t) => switch (stage) {
        Stage.strength => _strength(canvas, size, t),
        Stage.power => _power(canvas, size, t),
        Stage.stability => _stability(canvas, size, t),
        Stage.cardio => _cardio(canvas, size, t),
        Stage.stretching => _stretching(canvas, size, t),
        Stage.warmup => _warmup(canvas, size, t),
        Stage.rest => _rest(canvas, size, t),
      };

  Paint _fill(Color c) => Paint()..color = c..isAntiAlias = true;
  Paint _stroke(Color c, double w) => Paint()..color = c..strokeWidth = w..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..isAntiAlias = true;

  /// Fills a shape and rounds its corners with a stroke of the same colour.
  void _soft(Canvas c, Path p, Color col, [double round = 2.5]) {
    c.drawPath(p, _fill(col));
    c.drawPath(p, _stroke(col, round));
  }

  void _rrect(Canvas c, Offset at, double w, double h, double r, Paint p) =>
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: w, height: h), Radius.circular(r)), p);

  // ---- strength ----

  /// A dumbbell, rigid and perfectly straight, with only its shadow beneath it. It rests on its plates, is lifted
  /// slowly and under control, teetering a little left and right as it is picked up and settling level; at the top a
  /// small faded pop of light from the middle of the bar; then it is lowered, a touch quicker than it went up, level,
  /// back down onto its shadow.
  void _strength(Canvas c, Size s, double t) {
    final cx = s.width / 2, floor = s.height - 8;
    const plateR = 24.0, top = 38.0;
    final rest = floor - plateR;
    final rise = _seg(t, 0.1, 0.44);
    final up = t < 0.44 ? Curves.easeInOutSine.transform(rise) : t < 0.58 ? 1.0 : 1 - Curves.easeInOutSine.transform(_seg(t, 0.58, 0.852));
    final y = rest - up * (rest - top);
    final teeter = 0.06 * sin(2 * pi * 1.5 * rise) * sin(pi * rise);
    final h = 1 - up;
    c.drawOval(Rect.fromCenter(center: Offset(cx, floor), width: 80 + 30 * h, height: 4 + 3 * h), _fill(ink.line.withValues(alpha: 0.8 * h)));
    final pop = _seg(t, 0.45, 0.6);
    if (pop > 0 && pop < 1) {
      final e = Curves.easeOutCubic.transform(pop);
      c.drawCircle(Offset(cx, y), 8 + 22 * e, _stroke(ink.soft.withValues(alpha: 0.6 * (1 - pop)), 2));
      c.drawCircle(Offset(cx, y), 10 + 8 * e, Paint()
        ..shader = RadialGradient(colors: [ink.faint.withValues(alpha: 0.9 * (1 - pop)), ink.faint.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: Offset(cx, y), radius: 10 + 8 * e)));
    }
    c.save();
    c.translate(cx, y);
    c.rotate(teeter);
    c.drawLine(const Offset(-24, 0), const Offset(24, 0), _stroke(ink.muted, 6));
    for (var k = -3; k <= 3; k++) {
      c.drawLine(Offset(k * 5.0, -1.8), Offset(k * 5.0, 1.8), _stroke(ink.line, 1));
    }
    for (final sx in [-1.0, 1.0]) {
      _rrect(c, Offset(sx * 31, 0), 13, plateR * 2, 6, _fill(ink.strong));
      _rrect(c, Offset(sx * 45, 0), 11, 36, 5, _fill(Color.lerp(ink.strong, ink.soft, 0.3)!));
      _rrect(c, Offset(sx * 54, 0), 5, 14, 2.5, _fill(ink.muted));
      c.drawLine(Offset(sx * 31 - 3.5, -plateR + 6), Offset(sx * 31 - 3.5, plateR - 6), _stroke(ink.sheen.withValues(alpha: 0.22), 1.5));
    }
    c.restore();
  }

  // ---- power ----

  /// A burst with a wait in it: a small dot sits still for a second; over a slow second and a bit sparks are drawn
  /// in and it grows to a medium dot; it holds there a second, swelling faintly; then it pops, unhurried: two soft
  /// shockwaves, rounded rays in two lengths that shoot out and are drawn in towards their tips, a few sparks carried
  /// on, and it settles back small.
  void _power(Canvas c, Size s, double t) {
    final ctr = Offset(s.width / 2, s.height / 2);
    const g0 = 1.0 / 5, g1 = 2.2 / 5, release = 3.2 / 5, k = 3.6 / 5;
    double after(double from, double span) => _seg(t, release + from * k, release + (from + span) * k);
    if (t >= g0 - 0.02 && t < release) {
      for (var i = 0; i < 8; i++) {
        final d = i / 8 * 0.05;
        final p = Curves.easeInOutCubic.transform(_seg(t, g0 + d, g1 + d * 0.5));
        if (p <= 0 || p >= 1) continue;
        for (var g = 2; g >= 0; g--) {
          final pg = max(0.0, p - g * 0.035);
          final ang = 2 * pi * i / 8 + 0.4 + pg * 1.1;
          c.drawCircle(ctr + Offset(cos(ang), sin(ang)) * (12 + 38 * (1 - pg)), 3.0 - g * 0.8,
              _fill(ink.soft.withValues(alpha: (g == 0 ? 1.0 : 0.45 / g) * min(1.0, p * 5))));
        }
      }
      final ring = _ease(_seg(t, g0, g1));
      if (ring > 0) c.drawCircle(ctr, 40 - 22 * ring, _stroke(ink.soft.withValues(alpha: 0.55 * ring * (1 - _seg(t, release - 0.04, release))), 1.5 + ring));
    }
    for (final (delay, reach, width) in [(0.0, 50.0, 4.0), (0.06, 38.0, 2.5)]) {
      final w = after(delay, 0.36);
      if (w > 0 && w < 1) {
        c.drawCircle(ctr, 14 + (reach - 14) * Curves.easeOutQuart.transform(w), _stroke(ink.strong.withValues(alpha: (1 - w) * 0.8), width * (1 - w) + 0.5));
      }
    }
    if (t >= release && after(0, 0.36) < 1) {
      final out = Curves.easeOutExpo.transform(after(0, 0.1));
      final chase = Curves.easeInOutCubic.transform(after(0.08, 0.26));
      for (var i = 0; i < 12; i++) {
        final ang = 2 * pi * i / 12 + pi / 12;
        final reach = i.isEven ? 46.0 : 34.0;
        final r1 = 16 + (reach - 16) * out + 4 * chase;
        final r0 = 16 + (r1 - 16) * chase;
        if (r1 - r0 < 0.5) continue;
        final dir = Offset(cos(ang), sin(ang));
        c.drawLine(ctr + dir * r0, ctr + dir * r1, _stroke(ink.strong.withValues(alpha: 1 - 0.6 * chase), i.isEven ? 4 : 3));
      }
    }
    final sp = after(0.02, 0.44);
    if (sp > 0 && sp < 1) {
      for (var i = 0; i < 6; i++) {
        final ang = 2 * pi * i / 6 + pi / 6 + 0.1;
        c.drawCircle(ctr + Offset(cos(ang), sin(ang)) * (22 + 30 * Curves.easeOutCubic.transform(sp)), 2.4 * (1 - sp) + 0.8, _fill(ink.sheen.withValues(alpha: 1 - sp)));
      }
    }
    final grow = _ease(_seg(t, g0, g1));
    final hold = t >= g1 && t < release ? 0.6 * sin(pi * _seg(t, g1, release)) : 0.0;
    final popped = Curves.easeOutBack.transform(after(0, 0.06));
    final settle = _ease(after(0.06, 0.18));
    final r = t < release ? 4 + 7 * grow + hold : 11 + 5 * popped - 12 * settle;
    final glow = t < release ? grow : 1 - settle;
    if (glow > 0) {
      c.drawCircle(ctr, r + 14 * glow, Paint()
        ..shader = RadialGradient(colors: [ink.faint, ink.faint.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: ctr, radius: r + 14 * glow)));
    }
    final core = max(4.0, r);
    c.drawCircle(ctr, core, _fill(ink.strong));
    c.drawCircle(ctr + Offset(-core * 0.3, -core * 0.3), core * 0.28, _fill(ink.sheen.withValues(alpha: 0.35)));
  }

  // ---- stability ----

  static List<(double, double, double)>? _balanceTable; // computed once; a hot reload keeps it, so restart after tuning
  static const _balanceHalf = 11.0, _balanceKick = 1.0;

  /// One loop of a ball balanced on a board, simulated, in two halves: still and centred; a push rolls it slowly out
  /// almost to the end of the board, which tilts against it; it teeters back past the middle and out the other way,
  /// less each time, slowly settling; once it is nearly still it glides the last bit to dead centre, and rests about
  /// two seconds in all before the push from the other side.
  static List<(double, double, double)> _balance() {
    if (_balanceTable != null) return _balanceTable!;
    const g = 900.0, kp = 0.00203, kd = 0.00095, tau = 0.14, dt = 1 / 240;
    final out = <(double, double, double)>[];
    for (final side in [1.0, -1.0]) {
      var x = 0.0, v = 0.0, th = 0.0;
      double? still;
      var sx = 0.0, sv = 0.0, sth = 0.0;
      final steps = (_balanceHalf / dt).round();
      for (var step = 0; step < steps; step++) {
        final time = step * dt;
        if ((time - _balanceKick).abs() < dt / 2) v += side * 94;
        if (time >= _balanceKick && still == null) {
          final target = (-kp * x - kd * v).clamp(-0.2, 0.2);
          th += (target - th) * dt / tau;
          v += g * sin(th) * dt;
          x += v * dt;
          if (time > _balanceKick + 1.5 && x.abs() < 6 && v.abs() < 10 && th.abs() < 0.02) { still = time; sx = x; sv = v; sth = th; }
        }
        var ox = x, oth = th;
        if (still != null) {
          // the last bit, while the ball is still drifting: the board tips a touch against where it is heading to
          // bring it home, then levels; the ball carries its speed into the glide, so nothing hitches
          const glide = 1.4;
          final u = _seg(time, still, still + glide);
          final f = _ease(u);
          final heading = sx + 0.5 * sv;
          final against = -(heading == 0 ? side : heading.sign) * 0.03;
          ox = (2 * u * u * u - 3 * u * u + 1) * sx + (u * u * u - 2 * u * u + u) * glide * sv;
          oth = sth * (1 - f) + against * sin(pi * f);
        }
        if (step.isEven) out.add((ox, oth, v));
      }
    }
    return _balanceTable = out;
  }

  /// The balancing act: a rounded pivot with its pin, a mark for the middle of the board, the ball with a sheen and
  /// a soft contact shadow, the nudge shown as a ripple behind the ball. No floor and no level line.
  void _stability(Canvas c, Size s, double t) {
    final table = _balance();
    final (x, th, _) = table[(t * table.length).floor().clamp(0, table.length - 1)];
    final cx = s.width / 2, floor = s.height - 10;
    final pivot = Offset(cx, floor - 30);
    final tri = Path()..moveTo(pivot.dx, pivot.dy + 2)..lineTo(pivot.dx - 17, floor - 1)..lineTo(pivot.dx + 17, floor - 1)..close();
    _soft(c, tri, ink.soft, 4);
    c.save();
    c.translate(pivot.dx, pivot.dy - 4);
    c.rotate(th);
    _rrect(c, Offset.zero, 128, 8, 4, _fill(ink.strong));
    c.drawLine(const Offset(0, -1), const Offset(0, 1), _stroke(ink.faint, 3));
    final ball = Offset(x, -14);
    c.drawOval(Rect.fromCenter(center: Offset(x, -4.5), width: 16, height: 3), _fill(ink.line.withValues(alpha: 0.8)));
    final half = (t * 2) % 1;
    const kick = _balanceKick / _balanceHalf;
    final nudge = _seg(half, kick, kick + 0.05);
    if (nudge > 0 && nudge < 1) {
      final sx = t < 0.5 ? -1.0 : 1.0;
      for (final lag in [0.0, 0.35]) {
        final p = _seg(nudge, lag, 1);
        if (p <= 0) continue;
        final r = 12 + 12 * p;
        c.drawArc(Rect.fromCircle(center: ball, radius: r), sx < 0 ? pi - 0.6 : -0.6, 1.2, false, _stroke(ink.soft.withValues(alpha: 1 - p), 2));
      }
    }
    c.drawCircle(ball, 10, _fill(ink.strong));
    c.drawCircle(ball + const Offset(-3, -3.5), 3, _fill(ink.sheen.withValues(alpha: 0.4)));
    c.restore();
    c.drawCircle(pivot + const Offset(0, -4), 2.5, _fill(ink.faint));
  }

  // ---- cardio ----

  /// A heart drawn the even way: two round lobes that just touch in a deep, curved-in cleft at the top, and two
  /// straight sides that run on tangent from the lobes to meet at the bottom at about a right angle, so nothing kinks.
  /// About 86 wide and 80 tall at [scale] 1, centred on [ctr].
  Path _heartShape(Offset ctr, double scale) {
    final a = 34.0 * scale, r = a / sqrt2, rise = 1.644 * a;
    final bottom = ctr + Offset(0, 44 * scale);
    // each lobe's centre sits r out and `rise` up from the bottom point; the side leaves the bottom at the angle that
    // just grazes the lobe
    final toCentre = atan2(r, rise), graze = asin(r / sqrt(r * r + rise * rise));
    final side = sqrt(r * r + rise * rise - r * r);
    Offset tangent(double sx) => bottom + Offset(sx * sin(toCentre + graze), -cos(toCentre + graze)) * side;
    final left = tangent(-1), right = tangent(1), cleft = bottom + Offset(0, -rise);
    final heart = Path()
      ..moveTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..arcToPoint(cleft, radius: Radius.circular(r), clockwise: true, largeArc: true)
      ..arcToPoint(right, radius: Radius.circular(r), clockwise: true, largeArc: true)
      ..close();
    // a touch narrower than the geometry gives: 90% of the width, the same height
    return heart.transform(Float64List.fromList([0.9, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, ctr.dx * 0.1, 0, 0, 1]));
  }

  /// A heart with its heartbeat inside: the classic heartbeat line rolls in from the right and out to the left
  /// through the heart, fading at its sides. The heart swells lub-dub just as each beat comes in from the right, and a
  /// faint echo of its outline goes out with it.
  void _cardio(Canvas c, Size s, double t) {
    const beat = 120.0, amp = 18.0;
    final hc = Offset(s.width / 2, 54);
    final mid = hc.dy + 16; // low enough that the tall spike clears the cleft as it crosses the middle
    final x0 = hc.dx - 60, x1 = hc.dx + 60;
    double cyclic(double d) => d - (d + 0.5).floorToDouble();
    // the first spike's tip first shows inside the heart 41 px right of its middle (x0 + 101): the heart beats right
    // then, a quick lub and a quicker dub
    final enter = 0.4 - 101 / beat - (0.4 - 101 / beat).floorToDouble();
    final beatAt = enter - 0.013; // 26 ms ahead of the tip showing, so the swell reads as the beat that sends it
    final lub = 0.05 * exp(-pow(cyclic(t - beatAt) / 0.024, 2).toDouble()) + 0.03 * exp(-pow(cyclic(t - beatAt - 0.088) / 0.024, 2).toDouble());
    final heart = _heartShape(hc, 1 + lub);
    final echo = cyclic(t - beatAt);
    if (echo > 0 && echo < 0.45) {
      final e = echo / 0.45;
      c.drawPath(_heartShape(hc, 1 + 0.15 * Curves.easeOutCubic.transform(e)), _stroke(ink.soft.withValues(alpha: 0.5 * (1 - e)), 2));
    }
    c.drawPath(heart, _fill(ink.faint));
    c.save();
    c.clipPath(heart);
    double y(double x) => mid - amp * _ecgRound((x - x0) / beat + t);
    final line = Path()..moveTo(x0, y(x0));
    for (var x = x0 + 1.0; x <= x1; x += 1.0) { line.lineTo(x, y(x)); }
    c.drawPath(line, _stroke(ink.strong, 5)
      ..shader = LinearGradient(colors: [ink.strong.withValues(alpha: 0), ink.strong, ink.strong, ink.strong.withValues(alpha: 0)], stops: const [0, 0.1, 0.9, 1])
          .createShader(Rect.fromLTRB(x0, 0, x1, s.height)));
    c.restore();
    c.drawPath(heart, _stroke(ink.strong, 5));
  }

  /// The classic heartbeat: flat, then a tall spike up, a dip below the line, a shorter spike up and back down to
  /// flat. Each turn is rounded just enough to read smoothly at 5 px.
  static double _ecgRound(double u) {
    u = u - u.floorToDouble();
    double bump(double at, double w, double h) => h * exp(-pow((u - at) / w, 2).toDouble());
    return bump(0.4, 0.02, 1.0) - bump(0.45, 0.021, 0.5) + bump(0.5, 0.02, 0.55) - bump(0.545, 0.02, 0.14);
  }

  // ---- stretching ----

  /// A band as a ribbon: [half] its half length, [sag] how far its middle hangs, thinner in the middle by [thin].
  (Path, List<Offset>) _ribbon(double cx, double cy, double half, double sag, double thick, double thin) {
    const n = 96;
    final top = <Offset>[], bottom = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final u = i / n;
      final x = cx - half + 2 * half * u;
      final y = cy + sag * 4 * u * (1 - u);
      final slope = sag * 4 * (1 - 2 * u) / (2 * half);
      final nrm = Offset(-slope, 1) / sqrt(1 + slope * slope);
      final h = (thick - thin * sin(pi * u)) / 2;
      top.add(Offset(x, y) - nrm * h);
      bottom.add(Offset(x, y) + nrm * h);
    }
    final p = Path()..moveTo(top.first.dx, top.first.dy);
    for (final q in top.skip(1)) { p.lineTo(q.dx, q.dy); }
    for (final q in bottom.reversed) { p.lineTo(q.dx, q.dy); }
    return (p..close(), top);
  }

  /// A resistance band in one smooth motion with no kinks in it: out, a soft hold, back, a soft rest, every change of
  /// pace eased into the next. The ribbon brightens towards the middle as the tension builds, a sheen runs along its top
  /// edge, it runs into rounded grips, and soft chevrons show the pull at full stretch.
  void _stretching(Canvas c, Size s, double t) {
    final cx = s.width / 2, cy = s.height / 2 + 2;
    final k = _ease(_ease(0.5 - 0.5 * cos(2 * pi * t)));
    const rest = 26.0;
    final reach = min(28.0, s.width / 2 - 46 - rest);
    final half = rest + reach * k;
    final (shape, top) = _ribbon(cx, cy, half + 18, 9 * (1 - k) + 1, 10, 5.5 * k);
    final edge = Color.lerp(ink.soft, ink.strong, 0.45)!;
    final middle = Color.lerp(edge, ink.strong, k)!;
    c.drawPath(shape, Paint()
      ..shader = LinearGradient(colors: [edge, middle, middle, edge], stops: const [0, 0.35, 0.65, 1])
          .createShader(Rect.fromLTRB(cx - half - 18, cy - 20, cx + half + 18, cy + 20)));
    final sheen = Path()..moveTo(top[20].dx, top[20].dy + 1.6);
    for (final q in top.sublist(21, top.length - 20)) { sheen.lineTo(q.dx, q.dy + 1.6); }
    c.drawPath(sheen, _stroke(ink.sheen.withValues(alpha: 0.18 + 0.2 * k), 1.3));
    for (final sx in [-1.0, 1.0]) {
      final grip = Offset(cx + sx * (half + 18), cy);
      _rrect(c, grip, 14, 34, 7, _fill(ink.soft));
      _rrect(c, grip, 5, 22, 2.5, _fill(ink.strong));
    }
    final pull = _ease(_seg(k, 0.7, 1));
    if (pull > 0) {
      for (final sx in [-1.0, 1.0]) {
        for (final j in [0, 1]) {
          final x = cx + sx * (half + 32 + j * 8);
          final chevron = _stroke(ink.soft.withValues(alpha: pull * (j == 0 ? 1 : 0.5)), 2.2);
          c.drawLine(Offset(x, cy - 5), Offset(x + sx * 5, cy), chevron);
          c.drawLine(Offset(x + sx * 5, cy), Offset(x, cy + 5), chevron);
        }
      }
    }
  }

  // ---- warm-up ----

  /// A thermometer telling a little story, slow and fluid over twelve seconds: it rises a third, then another third,
  /// slips back to half, climbs all the way to the top mark, holds, and cools. Each move eases into the next. The
  /// scale runs exactly from the column's lowest reading to its highest, each mark lighting as the column reaches it;
  /// the bulb glows warmer and warmth rises off the top when it is hot.
  void _warmup(Canvas c, Size s, double t) {
    const keys = [(0.0, 0.06), (0.13, 0.36), (0.29, 0.68), (0.43, 0.5), (0.62, 1.0), (0.8, 1.0), (1.0, 0.06)];
    var level = keys.last.$2;
    for (var i = 0; i < keys.length - 1; i++) {
      final (ta, va) = keys[i];
      final (tb, vb) = keys[i + 1];
      if (t >= ta && t <= tb) {
        level = va + (vb - va) * Curves.easeInOutSine.transform((t - ta) / (tb - ta));
        break;
      }
    }
    level = level.clamp(0.0, 1.0);
    _drawThermo(c, s, t, level);
  }

  void _drawThermo(Canvas c, Size s, double t, double level) {
    final cx = s.width / 2 - 10;
    final bulb = Offset(cx, s.height - 30);
    const top = 20.0, tubeHalf = 8.0;
    final lowY = bulb.dy - 20, highY = top + 8;
    final colTop = lowY - (lowY - highY) * level;
    c.drawCircle(bulb, 20 + 6 * level, _fill(ink.faint.withValues(alpha: 0.7 * level)));
    final glass = Path.combine(PathOperation.union,
        Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - tubeHalf, top, cx + tubeHalf, bulb.dy), const Radius.circular(tubeHalf))),
        Path()..addOval(Rect.fromCircle(center: bulb, radius: 17)));
    c.drawPath(glass, _fill(ink.faint));
    // colTop is the column's top edge, so a full reading meets the top mark exactly
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - 4.5, colTop, cx + 4.5, bulb.dy), const Radius.circular(4.5)), _fill(ink.strong));
    c.drawCircle(bulb, 11.5, _fill(ink.strong));
    c.drawLine(Offset(cx - 1.5, colTop + 4), Offset(cx - 1.5, bulb.dy - 12), _stroke(ink.sheen.withValues(alpha: 0.35), 1.5));
    c.drawPath(glass, _stroke(ink.soft, 2));
    c.drawLine(Offset(cx - 4, top + 6), Offset(cx - 4, bulb.dy - 18), _stroke(ink.sheen.withValues(alpha: 0.18), 1.5));
    c.drawCircle(bulb + const Offset(-5, -5), 3, _fill(ink.sheen.withValues(alpha: 0.4)));
    const marks = 7;
    for (var i = 0; i < marks; i++) {
      final y = lowY - (lowY - highY) * i / (marks - 1);
      final lit = ((y - colTop + 3) / 3).clamp(0.0, 1.0); // lights over the last 3 px as the column arrives
      final major = i.isEven;
      c.drawLine(Offset(cx + 13, y), Offset(cx + (major ? 23 : 19), y), _stroke(Color.lerp(ink.line, ink.strong, lit)!, major ? 2 : 1.5));
    }
    final warm = _seg(level, 0.74, 0.92);
    if (warm > 0) {
      for (var j = 0; j < 3; j++) {
        final p = (t * 4 + j / 3) % 1;
        c.drawArc(Rect.fromCircle(center: Offset(cx, top + 2), radius: 7 + p * 9), -pi * 0.78, pi * 0.56, false,
            _stroke(ink.soft.withValues(alpha: warm * sin(pi * p) * 0.8), 2));
      }
    }
  }

  // ---- rest ----

  /// The breath, four counts in and four out: a soft disc grows and shrinks under three rings that swell one after
  /// another like a ripple, a slow glow behind it all, and a ring of dots drifts outward on the breath in and back on
  /// the breath out as it turns, so the whole thing opens and closes like a lung.
  void _rest(Canvas c, Size s, double t) {
    final ctr = Offset(s.width / 2, s.height / 2);
    final k = _breath(t);
    c.drawCircle(ctr, 52, Paint()
      ..shader = RadialGradient(colors: [ink.faint.withValues(alpha: 0.35 + 0.4 * k), ink.faint.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: ctr, radius: 52)));
    final disc = 12 + 24 * k;
    c.drawCircle(ctr, disc, _fill(ink.faint));
    for (final (lag, alpha, width) in [(0.1, 0.3, 1.4), (0.05, 0.55, 1.8), (0.0, 1.0, 2.2)]) {
      final r = 14 + 26 * _breath(t - lag) - lag * 40;
      c.drawCircle(ctr, r, _stroke(ink.soft.withValues(alpha: alpha), width));
    }
    for (var i = 0; i < 12; i++) {
      final ang = 2 * pi * i / 12 + t * 2 * pi / 12 - pi / 2;
      final r = 28 + 18 * _breath(t - 0.06);
      c.drawCircle(ctr + Offset(cos(ang), sin(ang)) * r, 1.4 + 0.8 * k, _fill(ink.soft.withValues(alpha: 0.35 + 0.5 * k)));
    }
    c.drawCircle(ctr, 5 + 2.5 * k, _fill(ink.strong));
  }

  @override
  bool shouldRepaint(_StagePainter old) => old.stage != stage || old.ink.strong != ink.strong;
}

/// The how-to as numbered steps, one sentence each.
