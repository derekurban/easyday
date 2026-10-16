import re
# ---- widgets.dart: replace TriBand with a smooth version
p='lib/ui/widgets.dart'
s=open(p,encoding='utf-8').read()
a=s.index('/// A calibration as one band with three thumbs')
new='''/// A calibration as one band with three thumbs: the fewest, the ideal, the most. Grab any thumb and it follows the
/// finger; the ideal pushes the others along. A tap on the track brings the nearest thumb. While dragging, a line says
/// what that thumb means.
class TriBand extends StatefulWidget {
  const TriBand({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged, this.icon, this.unit = '', this.hints, this.display});
  final String label;
  final Tri value;
  final int min;
  final int max;
  final IconData? icon;
  final String unit;
  final ValueChanged<Tri> onChanged;
  /// What each thumb means, shown while dragging it.
  final ({String min, String ideal, String max})? hints;
  final String Function(int)? display;
  @override
  State<TriBand> createState() => _TriBandState();
}

class _TriBandState extends State<TriBand> {
  int? active;        // 0 min, 1 ideal, 2 max
  double? dragValue;  // the active thumb's continuous value while dragging
  double grab = 0;    // finger to thumb offset in value units, so a grabbed thumb never jumps
  static const _pad = 16.0;

  String _d(int v) => widget.display?.call(v) ?? '$v${widget.unit}';
  double get _span => (widget.max - widget.min).toDouble();
  double _x(double v, double w) => _pad + (v - widget.min) / _span * (w - 2 * _pad);
  double _v(double x, double w) => (widget.min + (x - _pad) / (w - 2 * _pad) * _span).clamp(widget.min.toDouble(), widget.max.toDouble());

  void _start(double x, double w) {
    final t = widget.value;
    final xs = [_x(t.min.toDouble(), w), _x(t.ideal.toDouble(), w), _x(t.max.toDouble(), w)];
    var best = 1;
    var bestD = (xs[1] - x).abs();
    for (final i in [0, 2]) {
      final d = (xs[i] - x).abs();
      if (d < bestD - 0.5) { best = i; bestD = d; }
    }
    if (t.min == t.ideal && best == 0 && x > xs[0]) best = 1;
    if (t.max == t.ideal && best == 2 && x < xs[2]) best = 1;
    // grabbed: keep the offset; tapped elsewhere on the track: the thumb comes to the finger
    grab = bestD <= 28 ? _v(xs[best], w) - _v(x, w) : 0;
    setState(() { active = best; dragValue = _v(x, w) + grab; });
    _commit();
  }

  void _move(double x, double w) {
    setState(() => dragValue = (_v(x, w) + grab).clamp(widget.min.toDouble(), widget.max.toDouble()));
    _commit();
  }

  void _commit() {
    final v = dragValue!.round();
    final t = widget.value;
    final next = switch (active) { 0 => t.withMin(v), 2 => t.withMax(v), _ => t.withIdeal(v) };
    if (next != t) { HapticFeedback.selectionClick(); widget.onChanged(next); }
  }

  void _end() => setState(() { active = null; dragValue = null; });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final v = widget.value;
    final hints = widget.hints ?? (min: 'never fewer than this', ideal: 'the sweet spot', max: 'only on long workouts and hard days');
    final hint = switch (active) { 0 => 'At least ${_d(v.min)}: ${hints.min}.', 2 => 'Up to ${_d(v.max)}: ${hints.max}.', 1 => 'Ideally ${_d(v.ideal)}: ${hints.ideal}.', _ => null };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (widget.icon != null) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(widget.icon, size: 18, color: du.inkSecondary)),
          Expanded(child: Text(widget.label, style: t.bodyLarge)),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: m(context, durFast),
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: Text('${v.min} · ${v.ideal} · ${v.max}', key: ValueKey('${v.min}${v.ideal}${v.max}'), style: t.titleMedium?.copyWith(color: du.accentText)),
          ),
        ]),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final vals = [v.min.toDouble(), v.ideal.toDouble(), v.max.toDouble()];
          if (active != null && dragValue != null) {
            vals[active!] = dragValue!;
            if (active == 1) { if (vals[0] > vals[1]) vals[0] = vals[1]; if (vals[2] < vals[1]) vals[2] = vals[1]; }
            if (active == 0 && vals[1] < vals[0]) { vals[1] = vals[0]; if (vals[2] < vals[0]) vals[2] = vals[0]; }
            if (active == 2 && vals[1] > vals[2]) { vals[1] = vals[2]; if (vals[0] > vals[2]) vals[0] = vals[2]; }
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (d) => _start(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, w),
            onHorizontalDragEnd: (_) => _end(),
            onHorizontalDragCancel: _end,
            onTapDown: (d) => _start(d.localPosition.dx, w),
            onTapUp: (_) => _end(),
            onTapCancel: _end,
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                // smooth the thumbs into place after a snap; while dragging the active one follows the finger exactly
                tween: Tween(end: vals[0] * 10000 + vals[1] * 100 + vals[2] / 10),
                duration: m(context, active == null ? durBase : Duration.zero),
                curve: easeOut,
                builder: (context, packed, _) {
                  final a = (packed / 10000).floorToDouble(), rem = packed - a * 10000;
                  final b = (rem / 100).floorToDouble(), cc = (rem - b * 100) * 10;
                  final draw = active != null ? vals : [a, b, cc];
                  return CustomPaint(painter: _TriPainter(
                    xMin: _x(draw[0], w), xIdeal: _x(draw[1], w), xMax: _x(draw[2], w), x0: _pad, x1: w - _pad,
                    line: du.line, fill: du.accentLine, strong: du.accentStrong, surface: du.surface, active: active,
                  ));
                },
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('at least ${_d(v.min)}', style: t.labelSmall?.copyWith(color: active == 0 ? du.accentText : null)),
            Text('ideally ${_d(v.ideal)}', style: t.labelSmall?.copyWith(color: active == 1 ? du.accentText : null)),
            Text('up to ${_d(v.max)}', style: t.labelSmall?.copyWith(color: active == 2 ? du.accentText : null)),
          ]),
        ),
        AnimatedSize(
          duration: m(context, durBase),
          curve: easeOut,
          alignment: Alignment.topLeft,
          child: hint == null ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(top: 6), child: Text(hint, style: t.bodySmall?.copyWith(color: du.accentText))),
        ),
      ]),
    );
  }
}

class _TriPainter extends CustomPainter {
  _TriPainter({required this.xMin, required this.xIdeal, required this.xMax, required this.x0, required this.x1, required this.line, required this.fill, required this.strong, required this.surface, this.active});
  final double xMin, xIdeal, xMax, x0, x1;
  final Color line, fill, strong, surface;
  final int? active;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final track = Paint()..color = line..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), track);
    final band = Paint()..color = fill..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(xMin, y), Offset(xMax, y), band);
    void thumb(double x, double r, bool big, bool on) {
      if (on) canvas.drawCircle(Offset(x, y), r + 10, Paint()..color = strong.withValues(alpha: 0.14));
      canvas.drawCircle(Offset(x, y), r, Paint()..color = big ? strong : surface);
      if (!big) canvas.drawCircle(Offset(x, y), r, Paint()..color = strong..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }
    thumb(xMin, 8, false, active == 0);
    thumb(xMax, 8, false, active == 2);
    thumb(xIdeal, 11, true, active == 1);
  }
  @override
  bool shouldRepaint(_TriPainter o) => o.xMin != xMin || o.xIdeal != xIdeal || o.xMax != xMax || o.active != active || o.x1 != x1;
}
'''
s=s[:a]+new
s=s.replace("import 'package:flutter/material.dart';","import 'package:flutter/gestures.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';",1)
open(p,'w',encoding='utf-8').write(s)

# ---- theme.dart: difficulty as a word, not dots
p='lib/ui/theme.dart'
s=open(p,encoding='utf-8').read()
a=s.index('/// Cost as five dots.')
s=s[:a]+'''/// Difficulty as a word in a small pill: easy, medium, hard. Hard is filled, medium tinted, easy plain.
class DifficultyTag extends StatelessWidget {
  const DifficultyTag(this.difficulty, {super.key, this.large = false});
  final int difficulty;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final t = Theme.of(context).textTheme;
    final d = difficulty.clamp(1, 3);
    final bg = d == 3 ? du.accentStrong : d == 2 ? du.accentSubtle : du.surface;
    final line = d == 3 ? du.accentStrong : d == 2 ? du.accentLine : du.line;
    final ink = d == 3 ? du.onAccent : d == 2 ? du.accentText : du.inkSecondary;
    const words = {1: 'easy', 2: 'medium', 3: 'hard'};
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 5 : 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: line, width: 0.6)),
      child: Text(words[d]!, style: (large ? t.labelLarge : t.labelSmall)?.copyWith(color: ink, letterSpacing: 0)),
    );
  }
}
'''
open(p,'w',encoding='utf-8').write(s)

for p, old, new in [
  ('lib/ui/catalog.dart', 'CostDots(difficultyInPlay(e, st)),', 'DifficultyTag(difficultyInPlay(e, st)),'),
  ('lib/ui/exercise_card.dart', 'Row(children: [CostDots(difficulty, size: 10), const SizedBox(width: 10), Text(difficultyLabel[difficulty]!, style: t.titleMedium)]),', "Row(children: [DifficultyTag(difficulty, large: true), const SizedBox(width: 10), Expanded(child: Text('one hard set takes ${difficulty == 3 ? 'a lot' : difficulty == 2 ? 'some' : 'a little'} out of the whole body', style: t.bodySmall))]),"),
  ('lib/ui/session.dart', 'CostDots(e.difficulty),', 'DifficultyTag(e.difficulty),'),
]:
    s=open(p,encoding='utf-8').read()
    assert old in s, (p, old)
    s=s.replace(old,new,1)
    open(p,'w',encoding='utf-8').write(s)

# ---- goal editor: reps section without programs and the table
p='lib/ui/goal_editor.dart'
s=open(p,encoding='utf-8').read()
a=s.index("      const SectionHeader('Reps', icon: LucideIcons.repeat),")
b=s.index("      const SectionHeader('A workout plans', icon: LucideIcons.layers),")
new='''      const SectionHeader('Rep ranges', icon: LucideIcons.repeat),
      Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < g.bands.length; i++)
          Pressable(
            onTap: () => _editBand(context, i),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              const IconBadge(LucideIcons.repeat, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${rangeText(g.bands[i].range)} reps', style: t.bodyLarge),
                Text('${[3, 2, 1].where(g.bands[i].difficulties.contains).map((d) => difficultyName[d]!.toLowerCase()).join(', ')} exercises${_cycles(g, i)}', style: t.bodySmall),
              ])),
              Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
            ])),
          ),
        if (g.bands.length < maxBands)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _editBand(context, g.bands.length), icon: const Icon(LucideIcons.plus, size: 16), label: const Text('Add a rep range'))),
        const SizedBox(height: 4),
        Text('${program != null ? '${programLabel[program]!}, from the template. ' : ''}Tap a range to change its reps or which exercises it applies to. Same strength either way: the weight follows the reps.', style: t.bodySmall),
      ])),
      const SizedBox(height: 16),
'''
s=s[:a]+new+s[b:]
s=s.replace('''  String _rowText(int d) {
    final row = widget.goal.rowFor(d);
    return row.isEmpty ? 'no range of its own' : row.map(rangeText).join(', then ');
  }
''','''  /// " · cycles with 8 to 12" when another range shares a difficulty with this one.
  String _cycles(GoalConfig g, int i) {
    final others = <String>{};
    for (final d in g.bands[i].difficulties) {
      for (var k = 0; k < g.bands.length; k++) { if (k != i && g.bands[k].difficulties.contains(d)) others.add(rangeText(g.bands[k].range)); }
    }
    return others.isEmpty ? '' : ' · cycles with ${others.join(', ')}';
  }
''')
open(p,'w',encoding='utf-8').write(s)
print('ok')
