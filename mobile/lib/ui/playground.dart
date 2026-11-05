// Playground: debug builds only. The finish screen's tiles, rethought (2026-11-04), and since built into the real
// finish (logged.dart); kept here to try the next variations on: fewer words, and a step up that feels like one. Next time is a weight chip that opens Easier, Same and Harder as the same pills as the take (love it,
// it's fine, not for me): icons, the picked one with its word. Tried and set aside: a heart in the corner, three bare
// marks and a swipe for the take; arrows and hold-to-step-up for next time.
// Prototype tiles over a made-up workout, in the app's colours (palette.dart) and the Edges restraint; nothing here
// touches the user's data. The variations chosen move into the real finish (logged.dart), then leave. The sections
// explored before (the colour lab, ranks and calibration, the strength lab, the finish samples) were archived when
// this replaced them.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'fresh.dart';
import 'motion.dart';
import 'palette.dart';
import 'theme.dart';
import 'widgets.dart';

enum _K { levelUp, push, first, better, short, eased }

/// One exercise of the made-up workout: what happened, today's level, the step a level is, and where the app puts
/// next time (+1 a step up, 0 the same).
class _Sample {
  const _Sample(this.name, this.line, this.kind, this.now, this.step, {this.auto = 0, this.delta, this.unit = 'kg'});
  final String name, line;
  final _K kind;
  final double now, step;
  final int auto;
  final int? delta;
  final String unit;
}

const _samples = [
  _Sample('Barbell back squat', 'Every set at the top: 12, 12, 12.', _K.levelUp, 60, 2.5, auto: 1, delta: 18),
  _Sample('Barbell row', 'Went up to 42.5 kg yourself and made every set.', _K.push, 42.5, 2.5, auto: 1, delta: 13),
  _Sample('Barbell bench press', '14 reps at 47.5 kg found your weight.', _K.first, 52.5, 2.5),
  _Sample('Dumbbell curl', '3 more reps than last time.', _K.better, 12, 1, delta: 7),
  _Sample('Hanging knee raise', '11 a set, aiming for 13.', _K.short, 0, 1, unit: 'version'),
  _Sample('Upright row', 'Eased to 15 kg partway through.', _K.eased, 17.5, 2.5),
];

class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});
  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  bool dark = true;
  int replay = 0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(dark ? Brightness.dark : Brightness.light),
      child: Builder(builder: (context) {
        final t = Theme.of(context).textTheme;
        final du = context.du;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Playground'),
            actions: [
              IconButton(tooltip: 'Play again', icon: const Icon(LucideIcons.rotateCcw), onPressed: () => setState(() => replay++)),
              IconButton(tooltip: dark ? 'Light' : 'Dark', icon: Icon(dark ? LucideIcons.sun : LucideIcons.moon), onPressed: () => setState(() => dark = !dark)),
            ],
          ),
          body: Column(children: [
            Expanded(child: ListView(key: ValueKey('tiles$replay'), padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Text('The finish screen\'s tiles, rethought: fewer words, and a step up that feels like one. Try them; nothing here touches your workouts.',
                  style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
              const SizedBox(height: 14),
              for (final (i, x) in _samples.indexed) Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: Reveal(delay: Duration(milliseconds: 90 * i), child: _ProtoTile(sample: x))),
              const SizedBox(height: 6),
              Text('Tap a weight for easier, the same or harder. A step up is an event; ↺ plays the arrivals again.',
                  style: t.bodySmall?.copyWith(color: du.inkTertiary)),
            ])),
          ]),
        );
      }),
    );
  }
}

/// One prototype tile. Its look is the Edges restraint: plain, a thin edge in a win's colour, one accent. Next time moves
/// in steps; a step up is an event (the edge sweeps round, the weight counts up, a burst at the mark, a firm haptic), a
/// step down a quiet one.
class _ProtoTile extends StatefulWidget {
  const _ProtoTile({required this.sample});
  final _Sample sample;
  @override
  State<_ProtoTile> createState() => _ProtoTileState();
}

class _ProtoTileState extends State<_ProtoTile> with TickerProviderStateMixin {
  late int next = widget.sample.auto;
  String take = 'fine'; // love, fine, no
  bool open = false; // the chip's choices
  late final AnimationController burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  _Sample get x => widget.sample;
  bool get offered => x.auto > 0; // the app offers a step up

  @override
  void initState() {
    super.initState();
    // an earned step up arrives as an event
    if (next > 0) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _celebrate(quiet: true); });
  }

  @override
  void dispose() {
    burst.dispose();
    settle.dispose();
    super.dispose();
  }

  void _celebrate({bool quiet = false}) {
    if (MediaQuery.of(context).disableAnimations) return;
    if (!quiet) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 420), () { if (mounted) HapticFeedback.lightImpact(); });
    }
    burst.forward(from: 0);
  }

  void _set(int to) {
    to = to.clamp(-1, 1);
    if (to == next) return;
    final up = to > next && to == 1;
    setState(() => next = to);
    if (up) {
      _celebrate();
    } else {
      HapticFeedback.lightImpact();
      if (to < 0 && !MediaQuery.of(context).disableAnimations) settle.forward(from: 0);
    }
  }

  String _weight(double v) => x.unit == 'version' ? (v <= 0 ? 'Knees bent' : v == 1 ? 'Knees to chest' : 'Toes to bar') : '${v % 1 == 0 ? v.toInt() : v} ${x.unit}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final p = StatePalette.of(context);
    final up = next > 0;
    final down = next < 0;
    // the tile's colour: a step up in the win's (your push ember, else the earned dusk), a first time fresh, the rest none
    final sweep = x.kind == _K.push ? p.push : p.earned;
    final ink = x.kind == _K.push ? p.pushInk.of(context) : p.earnedInk.of(context);
    final edge = up ? sweep : x.kind == _K.first ? p.fresh : null;
    final calm = p.gentleInk.of(context);
    final (icon, markColor) = up
        ? (x.kind == _K.push ? LucideIcons.flame : LucideIcons.arrowUp, ink)
        : down ? (LucideIcons.arrowDown, calm)
        : switch (x.kind) {
            _K.first => (freshIcon, freshInk(context)),
            _K.better => (LucideIcons.trendingUp, du.accentText),
            _K.short => (LucideIcons.sprout, calm),
            _K.eased => (LucideIcons.feather, calm),
            _ => (LucideIcons.equal, du.inkSecondary),
          };
    final label = up ? (x.kind == _K.push ? 'YOUR PUSH' : offered ? 'LEVELLED UP' : 'STEPPING UP') : x.kind == _K.first ? 'FIRST TIME' : null;
    final target = x.now + next * x.step;
    final dur = m(context, durSlow);

    // the mark: its icon pops in as it changes, and a step up throws a burst of sparks
    final mark = SizedBox(width: 40, height: 40, child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Positioned(left: -40, top: -40, right: -40, bottom: -40, child: IgnorePointer(child: AnimatedBuilder(animation: burst,
          builder: (context, _) => CustomPaint(painter: _Sparks(burst.value, sweep))))),
      AnimatedContainer(duration: dur, width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: markColor.withValues(alpha: 0.13))),
      AnimatedSwitcher(
        duration: dur,
        transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: FadeTransition(opacity: a, child: c)),
        child: Icon(icon, key: ValueKey('$icon$markColor'), size: 18, color: markColor),
      ),
    ]));

    // next time, by the chosen control
    final weightStyle = t.titleSmall?.copyWith(color: up ? ink : down ? calm : x.kind == _K.first ? freshInk(context) : du.inkSecondary, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]);
    Widget weight() => TweenAnimationBuilder<double>(
          tween: Tween(end: target),
          duration: m(context, const Duration(milliseconds: 700)),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(_weight(x.unit == 'version' ? target : (v / (x.step / 2)).round() * (x.step / 2)), style: weightStyle),
        );
    final right = InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () { HapticFeedback.selectionClick(); setState(() => open = !open); },
      child: AnimatedContainer(duration: dur, padding: const EdgeInsets.fromLTRB(8, 5, 10, 5), decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: up || down ? (up ? ink : calm).withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(color: up || down ? Colors.transparent : du.line, width: 0.8),
      ), child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (up || down) Icon(up ? LucideIcons.arrowUp : LucideIcons.arrowDown, size: 14, color: weightStyle?.color),
        if (up || down) const SizedBox(width: 4),
        weight(),
      ])),
    );
    // the chip opened: easier, the same or harder, as the take's pills, the picked one with its word
    final below = !open ? null : Padding(padding: const EdgeInsets.only(left: 52, top: 12), child: ChoicePills<int>(
      label: 'Next time',
      value: next,
      onPick: _set,
      options: [
        (value: -1, icon: LucideIcons.minus, word: 'Easier', color: calm),
        (value: 0, icon: LucideIcons.equal, word: 'Same', color: du.accentText),
        (value: 1, icon: LucideIcons.plus, word: 'Harder', color: ink),
      ],
    ));

    // what the user thinks of it: only a first time asks, in the finish's own pills
    final takeRow = x.kind != _K.first ? null : Padding(padding: const EdgeInsets.only(left: 52, top: 12), child: ChoicePills<String>(
      label: 'Your take',
      value: take,
      onPick: (v) => setState(() => take = v),
      options: [
        (value: 'love', icon: LucideIcons.heart, word: 'Love it', color: const Color(0xFFE5484D)),
        (value: 'fine', icon: LucideIcons.thumbsUp, word: "It's fine", color: du.accentText),
        (value: 'no', icon: LucideIcons.thumbsDown, word: 'Not for me', color: du.warning),
      ],
    ));

    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        mark,
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedSize(duration: dur, curve: Curves.easeOutCubic, alignment: Alignment.topLeft, child: label == null
              ? const SizedBox(width: double.infinity)
              : Padding(padding: const EdgeInsets.only(bottom: 2), child: AnimatedSwitcher(duration: dur, child: x.kind == _K.first && !up
                  ? FreshText(key: const ValueKey('fresh'), child: Text(label, style: t.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w600)))
                  : Text(label, key: ValueKey(label), style: t.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w600, color: ink))))),
          Text(x.name, style: t.titleMedium),
          Text(x.line, style: t.bodyMedium?.copyWith(color: du.inkSecondary)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          right,
          if (x.delta != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('↑${x.delta}', style: t.labelMedium?.copyWith(color: du.accentText))),
        ]),
      ]),
      ?below,
      ?takeRow,
    ]);

    // the frame: plain, a thin edge in its colour; a step up sweeps the edge round once
    final framed = AnimatedBuilder(animation: Listenable.merge([burst, settle]), builder: (context, child) {
      final colors = edge ?? [du.line, du.line];
      final spin = burst.isAnimating ? burst.value : 0.0;
      final swell = sin(pi * spin);                                      // 0 → 1 → 0 over the burst
      final calmWash = settle.isAnimating ? sin(pi * settle.value) : 0.0;
      final wash = up ? 0.04 + 0.16 * swell : edge != null ? 0.04 : 0.0;
      final tint = up ? sweep[1] : colors[1 % colors.length];
      return Transform.scale(scale: 1 + 0.025 * swell, child: Container(
        padding: EdgeInsets.all(edge == null ? 0.6 : 1.4 + 0.8 * swell),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: spin > 0
              ? SweepGradient(colors: [...colors, colors.first], transform: GradientRotation(2 * pi * Curves.easeOutCubic.transform(spin)))
              : LinearGradient(colors: colors.length == 1 ? [colors.first, colors.first] : colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: edge == null ? const Color(0x0F000000) : colors[colors.length ~/ 2].withValues(alpha: 0.10 + 0.35 * swell), blurRadius: 14 + 26 * swell, offset: const Offset(0, 2))],
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color.alphaBlend(calm.withValues(alpha: 0.14 * calmWash), Color.alphaBlend(tint.withValues(alpha: wash), du.surface)),
            borderRadius: BorderRadius.circular(13.4),
          ),
          child: child,
        ),
      ));
    }, child: AnimatedSize(duration: dur, curve: Curves.easeOutCubic, alignment: Alignment.topCenter, child: body));

    return framed;
  }
}

/// A burst of sparks from the mark: eight, thrown out and fading, in the win's colours.
class _Sparks extends CustomPainter {
  _Sparks(this.t, this.colors);
  final double t;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    final e = Curves.easeOutCubic.transform(t);
    for (var k = 0; k < 12; k++) {
      final a = k * pi / 6 + (k.isEven ? 0.15 : -0.1);
      final r = 18 + (k.isEven ? 34 : 24) * e;
      canvas.drawCircle(c + Offset(cos(a), sin(a)) * r, (k.isEven ? 3.6 : 2.6) * (1 - t) + 0.6, Paint()..color = colors[k % colors.length].withValues(alpha: 1 - t * t));
    }
  }

  @override
  bool shouldRepaint(_Sparks old) => old.t != t;
}
