// The heart rate from the watch, on the finish's details: one line over the workout's time, the sets as quiet marks
// along the bottom so a climb can be matched to the set that caused it, and the three numbers above it. One series, so
// no legend: the title names it. Ink only; the line is the one thing with colour (the sun's orange). docs/app/WATCH.md.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/model.dart';
import '../logic/heart.dart';
import 'app.dart';
import 'theme.dart';

class HeartPanel extends StatelessWidget {
  const HeartPanel({super.key, required this.session, required this.summary});
  final Session session;
  final HeartSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final h = summary;
    Widget number(String value, String label) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: t.titleLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          Text(label, style: t.labelSmall?.copyWith(color: du.inkSecondary, letterSpacing: 0)),
        ]));
    return Panel(padding: const EdgeInsets.fromLTRB(16, 14, 16, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(LucideIcons.heartPulse, size: 18, color: du.inkSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text('Heart rate', style: t.titleMedium)),
        if (h.device.isNotEmpty) Flexible(child: Text(h.device, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: du.inkTertiary, letterSpacing: 0))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        number('${h.avg}', 'average bpm'),
        number('${h.peak}', 'peak bpm'),
        number(h.kcal == null ? '–' : '${h.kcal}', 'kcal'),
      ]),
      const SizedBox(height: 14),
      SizedBox(height: 120, child: Semantics(
        label: 'Heart rate over the workout, from ${h.low} to ${h.peak} beats a minute, ${h.avg} on average',
        child: CustomPaint(painter: _HeartPainter(session, h, line: du.art, ink: du.inkTertiary, grid: du.line, sets: du.accentLine, text: t.labelSmall!.copyWith(color: du.inkTertiary, letterSpacing: 0))),
      )),
    ]));
  }
}

class _HeartPainter extends CustomPainter {
  _HeartPainter(this.x, this.h, {required this.line, required this.ink, required this.grid, required this.sets, required this.text});
  final Session x;
  final HeartSummary h;
  final Color line, ink, grid, sets;
  final TextStyle text;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = h.points;
    final start = x.startedAt!;
    final end = x.endedAt ?? pts.last.t;
    final span = max(1, end.difference(start).inSeconds).toDouble();
    // the scale: the readings' range, opened to round tens so the labels are plain numbers
    final lo = ((h.low - 5) / 10).floor() * 10.0, hi = ((h.peak + 5) / 10).ceil() * 10.0;
    const left = 30.0, bottom = 22.0, setBand = 4.0;
    final w = size.width - left, plotH = size.height - bottom - setBand - 6;
    double px(DateTime t) => left + t.difference(start).inMilliseconds / 1000 / span * w;
    double py(num bpm) => plotH - (bpm - lo) / max(1, hi - lo) * plotH;

    void label(String s, Offset at, {bool right = false}) {
      final tp = TextPainter(text: TextSpan(text: s, style: text), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(right ? at.dx - tp.width : at.dx, at.dy - tp.height / 2));
    }

    // recessive grid: the bottom, the middle and the top of the scale
    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    for (final v in [lo, (lo + hi) / 2, hi]) {
      canvas.drawLine(Offset(left, py(v)), Offset(size.width, py(v)), gridPaint);
      label(v.round().toString(), Offset(left - 6, py(v)), right: true);
    }

    // the sets, as marks along the bottom: from I'm ready to the reps
    final setPaint = Paint()..color = sets;
    for (final e in x.exercises) {
      for (final s in e.sets) {
        if (s.start == null || s.at == null) continue;
        final a = px(s.start!), b = max(px(s.at!), px(s.start!) + 2);
        canvas.drawRRect(RRect.fromLTRBR(a, plotH + 6, b, plotH + 6 + setBand, const Radius.circular(2)), setPaint);
      }
    }

    // the line: 2 px, broken where the watch was off the wrist or the workout paused (a gap of more than a minute)
    final path = Path();
    DateTime? prev;
    for (final p in pts) {
      final o = Offset(px(p.t), py(p.bpm));
      if (prev == null || p.t.difference(prev).inSeconds > 60) { path.moveTo(o.dx, o.dy); } else { path.lineTo(o.dx, o.dy); }
      prev = p.t;
    }
    canvas.drawPath(path, Paint()..color = line..strokeWidth = 2..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);

    // the time along the bottom: the start and the end
    label('0:00', Offset(left, size.height - 7));
    label(mmss(span), Offset(size.width, size.height - 7), right: true);
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.h != h || old.line != line;
}
