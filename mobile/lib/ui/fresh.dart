// Finding the weight: one look for a lift that is new and calibrating, wherever it shows (docs/app/UI.md). The first
// time's colours on the finish screen, fresh mint to teal to blue: a gradient for labels and edges, one teal for ink
// and marks. Green stays the user's level and their progress; fresh is the app still finding out.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'theme.dart';
import 'palette.dart';

/// The fresh sweep: the first time's edge and label ([StatePalette.fresh]).
List<Color> freshColorsOf(BuildContext context) => StatePalette.of(context).fresh;

/// The fresh colour as a fill: the strip's calibration set, a tag's edge.
Color freshFillOf(BuildContext context) => StatePalette.of(context).freshFill;

/// The fresh colour as ink, readable on the surface in either theme.
Color freshInk(BuildContext context) => StatePalette.of(context).freshInk.of(context);

/// The icon of finding the weight: a compass, as on the finish screen's first time.
const freshIcon = LucideIcons.compass;

/// Text painted in the fresh sweep.
class FreshText extends StatelessWidget {
  const FreshText({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (b) => LinearGradient(colors: freshColorsOf(context)).createShader(b),
        child: child,
      );
}

/// A small fresh tag, "calibrating", with the compass: beside a lift's name while it finds its weight.
class FreshTag extends StatelessWidget {
  const FreshTag(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ink = freshInk(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Color.alphaBlend(freshFillOf(context).withValues(alpha: 0.12), context.du.surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: freshFillOf(context).withValues(alpha: 0.55), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(freshIcon, size: 11, color: ink),
        const SizedBox(width: 4),
        Text(text, style: t.labelSmall?.copyWith(color: ink, letterSpacing: 0, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
